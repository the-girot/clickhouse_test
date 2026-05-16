#!/usr/bin/env python3
"""
ООО «ПромСнаб Групп» — FMCG B2B дистрибьютор
STG Layer — fake data generator

Цепочка: Производители → ПромСнаб → Дилеры/ритейл-сети
Период:  2023-01-01 → 2026-04-30

Установка:  pip install faker pandas numpy
Запуск:     python generate_fmcg_stg.py
Вывод:      ./output/fmcg/*.csv  (UTF-8 с BOM, совместим с Excel/Windows)
"""

import pandas as pd
import numpy as np
from faker import Faker
import random, hashlib, os, glob
from datetime import date, timedelta

# ─── конфиг ─────────────────────────────────────────────────────────────────
OUT      = "output/fmcg"
ENC      = "utf-8-sig"   # UTF-8 с BOM — корректно читается на Windows
SEED     = 42
DATE_MIN = "2023-01-01"
DATE_MAX = "2026-04-30"
# ────────────────────────────────────────────────────────────────────────────

fake = Faker(["ru_RU"])
Faker.seed(SEED)
random.seed(SEED)
np.random.seed(SEED)
os.makedirs(OUT, exist_ok=True)


# ── утилиты ─────────────────────────────────────────────────────────────────

def rdec(lo, hi):
    return round(random.uniform(lo, hi), 2)

def rdate(s=DATE_MIN, e=DATE_MAX):
    s, e = date.fromisoformat(s), date.fromisoformat(e)
    return s + timedelta(days=random.randint(0, (e - s).days))

def rhash(v):
    return hashlib.md5(str(v).encode()).hexdigest()

def meta(src, bid=None):
    return {
        "_source_system": src,
        "_batch_id":      bid or f"batch_{random.randint(1000, 9999)}",
        "_ingested_at":   date.today(),
        "_is_deleted":    0,
    }

def save(df: pd.DataFrame, name: str):
    path = f"{OUT}/{name}.csv"
    df.to_csv(path, index=False, encoding=ENC)
    size = os.path.getsize(path) / 1024
    print(f"  {(name + '.csv'):<45} {len(df):>7} rows  {size:>8.1f} KB")
    return df

def seasonal(d: date) -> float:
    """Коэффициент сезонности по месяцу."""
    return {1:0.70, 2:0.85, 3:1.15, 4:1.15, 5:1.00, 6:0.90,
            7:0.85, 8:0.90, 9:1.05,10:1.10,11:1.15,12:1.30}.get(d.month, 1.0)


# ════════════════════════════════════════════════════════════════════════════
# СПРАВОЧНИКИ
# ════════════════════════════════════════════════════════════════════════════

print("\n── Справочники ─────────────────────────────────────────")

# 1. stg_company
save(pd.DataFrame([{
    "company_id":              1,
    "company_name":            "ООО ПромСнаб Групп",
    "company_short":           "ПромСнаб",
    "inn":                     "7743215890",
    "kpp":                     "774301001",
    "legal_address":           "г. Москва, ул. Складская, д. 14",
    "industry":                "FMCG Distribution",
    "base_currency":           "RUB",
    "fiscal_year_start_month": 1,
    "founded_at":              date(2010, 3, 15),
    "_row_hash":               rhash(1),
    **meta("1C", "batch_0001"),
}]), "stg_company")

# 2. stg_warehouses
WH_DEF = [
    (1,"WH-MSK","Москва Центральный",   "г. Москва, ул. Складская, д. 14",   "ЦФО"),
    (2,"WH-SPB","Санкт-Петербург",      "г. СПб, пр. Индустриальный, 55",    "СЗФО"),
    (3,"WH-EKB","Екатеринбург",         "г. Екатеринбург, ул. Заводская, 8", "УФО"),
]
save(pd.DataFrame([{
    "warehouse_id": i, "warehouse_code": c, "warehouse_name": n,
    "address": a, "region": r, "is_active": 1,
    "_row_hash": rhash(i), **meta("1C", "batch_0001"),
} for i, c, n, a, r in WH_DEF]), "stg_warehouses")

# 3. stg_suppliers  — 15 производителей
SUP_NAMES = [
    "Henkel Россия", "P&G Россия", "Unilever Россия", "Нэфис Косметикс",
    "Аист Завод", "Невская Косметика", "ЭФКО Ингредиенты", "Юнилевер Русь",
    "Сигма Косметика", "ТД Красная Линия", "РосХимПром", "БытХимТорг",
    "АгроПромСнаб", "МолПродРесурс", "ПромМаркет",
]
suppliers = []
for i, nm in enumerate(SUP_NAMES, 1):
    suppliers.append({
        "supplier_id":         i,
        "supplier_name":       nm,
        "supplier_code":       f"SUP{i:03d}",
        "country_code":        random.choice(["RU","RU","RU","DE","NL"]),
        "payment_terms_days":  random.choice([30, 45, 60, 90]),
        "credit_limit":        rdec(500_000, 10_000_000),
        "status":              "active",
        "_row_hash":           rhash(i),
        **meta("1C", "batch_0001"),
    })
save(pd.DataFrame(suppliers), "stg_suppliers")

# 4. stg_clients  — 120 дилеров (сегменты A/B/C, 10 регионов)
CLIENT_TYPES = ["Дилер","Ритейл-сеть","Оптовик","Гипермаркет","Мини-сеть"]
REGIONS      = [
    "Москва и МО","Санкт-Петербург","Екатеринбург","Новосибирск",
    "Казань","Краснодар","Нижний Новгород","Ростов-на-Дону","Уфа","Самара",
]
clients = []
for i in range(1, 121):
    seg    = random.choices(["A","B","C"], weights=[15,45,40])[0]
    credit = {"A": rdec(1_000_000, 5_000_000),
              "B": rdec(200_000, 1_000_000),
              "C": rdec(50_000, 200_000)}[seg]
    clients.append({
        "client_id":            i,
        "client_name":          fake.company(),
        "client_code":          f"CLI{i:04d}",
        "client_type":          random.choice(CLIENT_TYPES),
        "segment":              seg,
        "region":               random.choice(REGIONS),
        "inn":                  fake.numerify("##########"),
        "payment_terms_days":   random.choice([7, 14, 21, 30, 45]),
        "credit_limit":         credit,
        "assigned_manager_id":  random.randint(1, 10),
        "warehouse_id":         random.choices([1,2,3], weights=[50,30,20])[0],
        "status":               random.choice(["active","active","active","inactive"]),
        "registered_at":        rdate("2018-01-01","2023-06-01"),
        "_row_hash":            rhash(i),
        **meta("CRM"),
    })
save(pd.DataFrame(clients), "stg_clients")

# 5. stg_managers  — 10 торговых представителей
MGR_NAMES = [
    "Иванов Алексей","Смирнова Ольга","Кузнецов Дмитрий","Попова Анна",
    "Новиков Андрей","Морозова Елена","Волков Сергей","Лебедева Наталья",
    "Козлов Игорь","Соколова Мария",
]
DEPTS = ["Отдел продаж Москва","Отдел продаж Регионы","КАМ-отдел"]
managers = []
for i, nm in enumerate(MGR_NAMES, 1):
    managers.append({
        "manager_id": i,
        "full_name":  nm,
        "department": random.choice(DEPTS),
        "region":     random.choice(REGIONS),
        "hire_date":  rdate("2015-01-01","2023-01-01"),
        "status":     "active",
        "_row_hash":  rhash(i),
        **meta("HR","batch_0001"),
    })
save(pd.DataFrame(managers), "stg_managers")

# 6. stg_products  — 80 SKU в 4 категориях
CATS = {
    "Бытовая химия": {
        "brands":  ["Persil","Tide","Fairy","Comet","Domestos","Vanish"],
        "subcats": ["Стиральные порошки","Средства для посуды","Чистящие средства","Кондиционеры"],
        "price":   (120, 850),
    },
    "Личная гигиена": {
        "brands":  ["Dove","Nivea","Head Shoulders","Palmolive","Schauma"],
        "subcats": ["Шампуни","Гели для душа","Зубные пасты","Дезодоранты"],
        "price":   (90, 600),
    },
    "Продукты питания": {
        "brands":  ["Bonduelle","Слобода","Юг Руси","Мистраль","Makfa"],
        "subcats": ["Масла растительные","Крупы","Консервация","Соусы"],
        "price":   (50, 400),
    },
    "Бумажная продукция": {
        "brands":  ["Zewa","Kleenex","Soffione","Familia"],
        "subcats": ["Туалетная бумага","Бумажные полотенца","Салфетки"],
        "price":   (60, 350),
    },
}
PACK_LABELS = ["0.5л","1л","1.5л","400г","900г","1кг","2кг","упак"]
products = []
pid = 1
for cat, cfg in CATS.items():
    for _ in range(20):
        brand  = random.choice(cfg["brands"])
        subcat = random.choice(cfg["subcats"])
        bp     = rdec(*cfg["price"])
        cost   = round(bp / (1 + random.uniform(0.12, 0.30)), 2)
        products.append({
            "product_id":      pid,
            "sku_code":        f"SKU{pid:04d}",
            "product_name":    f"{brand} {subcat} {random.choice(PACK_LABELS)}",
            "brand":           brand,
            "category":        cat,
            "subcategory":     subcat,
            "unit_of_measure": "шт",
            "pack_size":       random.choice([1, 6, 12, 24]),
            "base_price":      bp,
            "purchase_price":  cost,
            "vat_rate":        0.20,
            "min_order_qty":   random.choice([1, 6, 12]),
            "supplier_id":     random.randint(1, 15),
            "warehouse_id":    random.choices([1,2,3], weights=[50,30,20])[0],
            "is_active":       random.choice([1,1,1,0]),
            "launched_at":     rdate("2020-01-01","2023-12-31"),
            "_row_hash":       rhash(pid),
            **meta("ERP"),
        })
        pid += 1
save(pd.DataFrame(products), "stg_products")

# 7. stg_accounts  — план счетов с мэппингом P&L / BS / CF
ACC_DEF = [
    # id, code, name, type, stmt, bs_group, cf_section, pl_group, pl_sign, is_monetary
    ( 1,"1010","Касса",                     "Asset",    "BS","Current_Assets",         "Operating",  None,            1, 1),
    ( 2,"1020","Расчётный счёт",            "Asset",    "BS","Current_Assets",         "Operating",  None,            1, 1),
    ( 3,"1210","Дебиторская задолженность", "Asset",    "BS","Current_Assets",         None,         None,            1, 0),
    ( 4,"1310","Товарные запасы",           "Asset",    "BS","Current_Assets",         None,         None,            1, 0),
    ( 5,"1510","Основные средства",         "Asset",    "BS","Non_Current_Assets",     None,         None,            1, 0),
    ( 6,"2010","Кредиторская задолженность","Liability","BS","Current_Liabilities",    None,         None,           -1, 0),
    ( 7,"2110","Краткосрочные займы",       "Liability","BS","Current_Liabilities",    "Financing",  None,           -1, 0),
    ( 8,"3010","Уставный капитал",          "Equity",   "BS","Equity",                 None,         None,           -1, 0),
    ( 9,"3020","Нераспределённая прибыль",  "Equity",   "BS","Equity",                 None,         None,           -1, 0),
    (10,"4010","Выручка от продаж",         "Revenue",  "PL", None,                    None,         "Revenue",       1, 0),
    (11,"5010","Себестоимость товаров",      "Expense",  "PL", None,                    None,         "COGS",         -1, 0),
    (12,"6010","Зарплата и взносы",         "Expense",  "PL", None,                    "Operating",  "OPEX",         -1, 0),
    (13,"6020","Маркетинг и реклама",       "Expense",  "PL", None,                    "Operating",  "OPEX",         -1, 0),
    (14,"6030","Аренда склада",             "Expense",  "PL", None,                    "Operating",  "OPEX",         -1, 0),
    (15,"6040","Амортизация",               "Expense",  "PL", None,                    None,         "Depreciation", -1, 0),
    (16,"6050","Логистика и доставка",      "Expense",  "PL", None,                    "Operating",  "OPEX",         -1, 0),
    (17,"6060","Административные расходы",  "Expense",  "PL", None,                    "Operating",  "OPEX",         -1, 0),
    (18,"7020","Проценты по кредитам",      "Expense",  "PL", None,                    "Financing",  "Financial",    -1, 0),
    (19,"8010","Налог на прибыль",          "Expense",  "PL", None,                    None,         "Tax",          -1, 0),
]
save(pd.DataFrame([{
    "account_id": aid, "account_code": code, "account_name": name,
    "account_type": atype, "statement_type": st, "bs_group": bsg,
    "cf_section": cf, "pl_group": plg, "pl_sign": sign, "is_monetary": mon,
    "normal_balance": "Debit" if atype in ("Asset","Expense") else "Credit",
    "_row_hash": rhash(aid), **meta("1C","batch_0001"),
} for aid,code,name,atype,st,bsg,cf,plg,sign,mon in ACC_DEF]), "stg_accounts")


# ════════════════════════════════════════════════════════════════════════════
# ТРАНЗАКЦИИ
# ════════════════════════════════════════════════════════════════════════════

print("\n── Транзакции ──────────────────────────────────────────")

# 8. stg_purchase_orders + stg_purchase_order_lines
po_list, pol_list, pol_id = [], [], 1
for i in range(1, 2401):
    sup_id   = random.randint(1, 15)
    po_date  = rdate()
    exp_del  = po_date + timedelta(days=random.choice([7,14,21,30]))
    act_del  = exp_del + timedelta(days=random.randint(-3,10)) if random.random() > 0.1 else None
    n_lines  = random.randint(2, 8)
    total    = 0.0
    for _ in range(n_lines):
        prod  = products[random.randint(0, 79)]
        qty   = random.randint(50, 2000)
        price = round(prod["purchase_price"] * random.uniform(0.95, 1.05), 2)
        total += qty * price
        pol_list.append({
            "po_line_id":    pol_id,
            "po_id":         i,
            "product_id":    prod["product_id"],
            "sku_code":      prod["sku_code"],
            "category":      prod["category"],
            "quantity":      qty,
            "unit_price":    price,
            "line_amount":   round(qty * price, 2),
            "received_qty":  qty if act_del else 0,
            "_row_hash":     rhash(pol_id),
            **meta("ERP"),
        })
        pol_id += 1
    po_list.append({
        "po_id":              i,
        "po_code":            f"PO{i:06d}",
        "supplier_id":        sup_id,
        "warehouse_id":       random.choices([1,2,3], weights=[50,30,20])[0],
        "po_date":            po_date,
        "expected_delivery":  exp_del,
        "actual_delivery":    act_del,
        "status":             random.choice(["delivered","delivered","delivered","partial","cancelled"]),
        "currency_code":      "RUB",
        "total_amount":       round(total, 2),
        "_row_hash":          rhash(i),
        **meta("ERP"),
    })
save(pd.DataFrame(po_list),  "stg_purchase_orders")
save(pd.DataFrame(pol_list), "stg_purchase_order_lines")

# 9. stg_sales_orders + stg_sales_order_lines
# Генерируем даты с сезонностью (~12 заказов/день)
all_dates = []
d = date(2023, 1, 1)
while d <= date(2026, 4, 30):
    n = max(1, int(random.gauss(12 * seasonal(d), 3)))
    all_dates.extend([d] * n)
    d += timedelta(days=1)
random.shuffle(all_dates)
all_dates = sorted(all_dates[:14400])

so_list, sol_list, sol_id = [], [], 1
for i, ord_date in enumerate(all_dates, 1):
    client   = clients[random.randint(0, 119)]
    discount = random.choices([0, 0.03, 0.05, 0.07, 0.10], weights=[50,20,15,10,5])[0]
    pay_st   = random.choices(["paid","partial","unpaid"], weights=[60,25,15])[0]
    n_lines  = random.randint(1, 6)
    total    = 0.0
    for _ in range(n_lines):
        prod  = products[random.randint(0, 79)]
        qty   = random.randint(6, 500)
        price = round(prod["base_price"] * (1 - discount) * random.uniform(0.97, 1.03), 2)
        cost  = prod["purchase_price"]
        gp    = round(qty * (price - cost), 2)
        total += qty * price
        sol_list.append({
            "order_line_id":    sol_id,
            "order_id":         i,
            "product_id":       prod["product_id"],
            "sku_code":         prod["sku_code"],
            "category":         prod["category"],
            "brand":            prod["brand"],
            "quantity":         qty,
            "unit_price":       price,
            "unit_cost":        cost,
            "line_revenue":     round(qty * price, 2),
            "line_cogs":        round(qty * cost, 2),
            "line_gross_profit":gp,
            "_row_hash":        rhash(sol_id),
            **meta("1C"),
        })
        sol_id += 1
    so_list.append({
        "order_id":       i,
        "order_code":     f"SO{i:07d}",
        "client_id":      client["client_id"],
        "manager_id":     client["assigned_manager_id"],
        "warehouse_id":   client["warehouse_id"],
        "order_date":     ord_date,
        "shipment_date":  ord_date + timedelta(days=random.choice([1,2,3])),
        "status":         random.choices(["completed","partial","cancelled"], weights=[70,20,10])[0],
        "payment_status": pay_st,
        "currency_code":  "RUB",
        "discount_pct":   discount,
        "total_amount":   round(total, 2),
        "_row_hash":      rhash(i),
        **meta("1C"),
    })
save(pd.DataFrame(so_list),  "stg_sales_orders")
save(pd.DataFrame(sol_list), "stg_sales_order_lines")

# 10. stg_invoices  — AR (клиенты) + AP (поставщики)
invs = []
inv_id = 1
# AR
for so in so_list:
    if so["status"] == "cancelled":
        continue
    cl      = clients[so["client_id"] - 1]
    pt      = cl["payment_terms_days"]
    inv_d   = so["order_date"]
    due_d   = inv_d + timedelta(days=pt)
    amt     = so["total_amount"]
    paid_pct= {"paid":1.0,"partial":random.uniform(0.3,0.8),"unpaid":0.0}[so["payment_status"]]
    paid    = round(amt * paid_pct, 2)
    today   = date(2026, 5, 14)
    overdue = max((today - due_d).days, 0) if paid < amt else 0
    invs.append({
        "invoice_id":       inv_id,
        "invoice_code":     f"AR-{inv_id:07d}",
        "invoice_type":     "AR",
        "counterparty_id":  so["client_id"],
        "counterparty_type":"client",
        "order_id":         so["order_id"],
        "invoice_date":     inv_d,
        "due_date":         due_d,
        "currency_code":    "RUB",
        "amount":           amt,
        "paid_amount":      paid,
        "outstanding":      round(amt - paid, 2),
        "days_overdue":     overdue,
        "status":           so["payment_status"],
        "_row_hash":        rhash(inv_id),
        **meta("1C"),
    })
    inv_id += 1
# AP
for po in po_list:
    if po["status"] == "cancelled":
        continue
    sup    = suppliers[po["supplier_id"] - 1]
    inv_d  = po["actual_delivery"] or po["po_date"]
    if not isinstance(inv_d, date):
        inv_d = po["po_date"]
    due_d  = inv_d + timedelta(days=sup["payment_terms_days"])
    amt    = po["total_amount"]
    paid_pct= random.choices([1.0, random.uniform(0.5,0.9), 0.0], weights=[65,25,10])[0]
    paid   = round(amt * paid_pct, 2)
    today  = date(2026, 5, 14)
    overdue= max((today - due_d).days, 0) if paid < amt else 0
    invs.append({
        "invoice_id":       inv_id,
        "invoice_code":     f"AP-{inv_id:07d}",
        "invoice_type":     "AP",
        "counterparty_id":  po["supplier_id"],
        "counterparty_type":"supplier",
        "order_id":         po["po_id"],
        "invoice_date":     inv_d,
        "due_date":         due_d,
        "currency_code":    "RUB",
        "amount":           amt,
        "paid_amount":      paid,
        "outstanding":      round(amt - paid, 2),
        "days_overdue":     overdue,
        "status":           random.choice(["paid","paid","partial","unpaid"]),
        "_row_hash":        rhash(inv_id),
        **meta("1C"),
    })
    inv_id += 1
save(pd.DataFrame(invs), "stg_invoices")

# 11. stg_inventory_movements  — приход / отгрузка / списание
moves = []
for pol in pol_list[:4000]:
    moves.append({
        "move_id":        len(moves)+1,
        "move_type":      "receipt",
        "reference_type": "purchase_order",
        "reference_id":   pol["po_id"],
        "product_id":     pol["product_id"],
        "warehouse_id":   random.choices([1,2,3], weights=[50,30,20])[0],
        "quantity":       pol["received_qty"],
        "unit_cost":      pol["unit_price"],
        "move_date":      rdate(),
        "_row_hash":      rhash(len(moves)+1),
        **meta("WMS"),
    })
for sol in sol_list[:6000]:
    moves.append({
        "move_id":        len(moves)+1,
        "move_type":      "shipment",
        "reference_type": "sales_order",
        "reference_id":   sol["order_id"],
        "product_id":     sol["product_id"],
        "warehouse_id":   random.choices([1,2,3], weights=[50,30,20])[0],
        "quantity":       -sol["quantity"],
        "unit_cost":      sol["unit_cost"],
        "move_date":      rdate(),
        "_row_hash":      rhash(len(moves)+1),
        **meta("WMS"),
    })
for _ in range(300):
    prod = products[random.randint(0,79)]
    moves.append({
        "move_id":        len(moves)+1,
        "move_type":      "writeoff",
        "reference_type": "writeoff_act",
        "reference_id":   random.randint(1,50),
        "product_id":     prod["product_id"],
        "warehouse_id":   random.choices([1,2,3], weights=[50,30,20])[0],
        "quantity":       -random.randint(1,50),
        "unit_cost":      prod["purchase_price"],
        "move_date":      rdate(),
        "_row_hash":      rhash(len(moves)+1),
        **meta("WMS"),
    })
save(pd.DataFrame(moves), "stg_inventory_movements")

# 12. stg_gl_postings  — ежедневные бухгалтерские проводки
gl, gl_id = [], 1
d = date(2023, 1, 1)
while d <= date(2026, 4, 30):
    sw = seasonal(d)
    entries = [
        # (account_id, doc_type, description, base_amount_fn)
        (10, "SalesInvoice", "Выручка от реализации",
            rdec(800_000, 1_500_000) * sw),
        (11, "CostOfSales",  "Себестоимость продаж",
            rdec(800_000, 1_500_000) * sw * random.uniform(0.60, 0.72)),
        (12, "Payroll",      "Зарплата и взносы",
            rdec(150_000, 200_000) / 20),
        (13, "Marketing",    "Маркетинг и реклама",
            rdec(20_000, 80_000) * sw),
        (14, "Rent",         "Аренда склада",
            rdec(30_000, 40_000) / 20),
        (15, "Depreciation", "Амортизация",
            rdec(8_000, 12_000)),
        (16, "Logistics",    "Логистика и доставка",
            rdec(800_000, 1_500_000) * sw * random.uniform(0.04, 0.07)),
        (17, "Admin",        "Административные расходы",
            rdec(15_000, 30_000)),
    ]
    for acc_id, doc_type, desc, amt in entries:
        contra = 2 if acc_id not in (10, 11) else (3 if acc_id == 10 else 4)
        gl.append({
            "gl_id":         gl_id,
            "posting_date":  d,
            "doc_type":      doc_type,
            "account_id":    acc_id,
            "contra_account_id": contra,
            "amount_base":   round(amt, 2),
            "currency_code": "RUB",
            "description":   desc,
            "scenario_id":   1,
            "_row_hash":     rhash(gl_id),
            **meta("1C"),
        })
        gl_id += 1
    d += timedelta(days=1)
save(pd.DataFrame(gl), "stg_gl_postings")

# 13. stg_marketing_spend  — расходы по рекламным кампаниям
PLATFORMS  = ["Яндекс.Директ","VK Реклама","Telegram Ads","Email-рассылки","Выставки/BTL","SEO"]
CAMP_TYPES = ["Трафик","Охват","Конверсия","Лояльность","Сезонный промо"]
mkts, camp_id = [], 1
d = date(2023, 1, 1)
while d <= date(2026, 4, 30):
    sw   = seasonal(d)
    plat = random.choice(PLATFORMS)
    mkts.append({
        "spend_id":      len(mkts)+1,
        "campaign_id":   ((d.year-2023)*12 + d.month),
        "campaign_name": f"{random.choice(CAMP_TYPES)} {plat} {d.year}-{d.month:02d}",
        "platform":      plat,
        "spend_date":    d,
        "impressions":   int(random.gauss(50_000, 20_000) * sw),
        "clicks":        int(random.gauss(2_000, 800) * sw),
        "conversions":   int(random.gauss(80, 30) * sw),
        "spend_amount":  round(rdec(5_000, 25_000) * sw, 2),
        "currency_code": "RUB",
        "_row_hash":     rhash(len(mkts)+1),
        **meta("CRM"),
    })
    d += timedelta(days=1)
save(pd.DataFrame(mkts), "stg_marketing_spend")


# ════════════════════════════════════════════════════════════════════════════
# ИТОГОВЫЙ ОТЧЁТ
# ════════════════════════════════════════════════════════════════════════════

print()
files = sorted(glob.glob(f"{OUT}/*.csv"))
total_rows, total_kb = 0, 0
print("═" * 60)
print("  FILE                                       ROWS      SIZE")
print("═" * 60)
for f in files:
    rows = sum(1 for _ in open(f, encoding="utf-8-sig")) - 1
    size = os.path.getsize(f) / 1024
    total_rows += rows
    total_kb   += size
    print(f"  {os.path.basename(f):<43} {rows:>6}  {size:>7.1f} KB")
print("═" * 60)
print(f"  ИТОГО: {total_rows:>10,} строк | {total_kb:>8.1f} KB")
print("═" * 60)
print(f"\n  Вывод: {os.path.abspath(OUT)}")
