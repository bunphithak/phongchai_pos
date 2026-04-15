# คู่มือ Backend สำหรับ Phongchai POS (ทุกฟีเจอร์ในแอป)

เอกสารนี้ใช้สองอย่างพร้อมกัน:

1. **ฝั่ง backend / ทีม API** — รู้ว่าต้องทำ endpoint, payload และพฤติกรรมอะไรบ้าง  
2. **ตัวเองตอน wire แอป** — ดูว่าแต่ละเรื่องไปแก้/เรียกใช้ที่ไฟล์ไหนใน Flutter

---

## สรุปการตั้งค่าแอป

| รายการ | ที่มา |
|--------|--------|
| Base URL | `.env` → `API_BASE_URL` (อ่านใน `lib/core/config/app_config.dart`) |
| อัตราแลกแต้ม | `.env` → `POINT_EXCHANGE_RATE` + ค่าที่ซิงค์จาก backend (เก็บใน `SharedPreferences` ผ่าน `AppConfig.setPointExchangeRateFromSync`) |
| ซิงค์ / purge วัน | `.env` → `POS_PURGE_SYNCED_DAYS` |
| เชื่อมบริการซิงค์ | `lib/core/sync/pos_sync_service.dart` + `lib/features/pos/providers/pos_sync_provider.dart` |
| HTTP client กลาง (ยังว่าง) | `lib/data/remote/api_client.dart` — ตั้งใจให้ใส่ `http`/`dio` ที่นี่ |
| Local storage กลาง (ยังว่าง) | `lib/data/local/local_storage.dart` |

---

## ตารางฟีเจอร์ → Backend ต้องมีอะไร → ไฟล์ Flutter ที่ต้องไปแตะ

| ฟีเจอร์ในแอป | Backend ควรเตรียม (สรุป) | จุดที่แก้ใน Flutter (เมื่อต่อ API) |
|--------------|---------------------------|--------------------------------------|
| **ล็อกอินพนักงาน (PIN 6 หลัก)** | ตรวจ PIN / ออก token (หรือ JWT) ผูกกับพนักงาน | `lib/features/auth/providers/auth_provider.dart` (`tryLoginWithPin`), `lib/features/auth/presentation/login_screen.dart` — ตอนนี้ดึงจาก `MockDataStore` |
| **แคตตาล็อกสินค้า + สต็อก** | Pull delta ตาม `updated_at` | `lib/core/sync/pos_sync_service.dart` (`pullProductsOnStartup`), `lib/data/mock/mock_data_store.dart` (แทนที่ mock), `lib/features/pos/domain/barcode_catalog.dart` |
| **สแกน/ค้นหาสินค้า** | ใช้ข้อมูลจาก Pull ลง SQLite / memory เดียวกับแคตตาล็อก | `lib/features/pos/presentation/product_search_dialog.dart` (เรียก `MockDataStore.searchCatalog` อยู่) |
| **ตะกร้า / ส่วนลด / VAT** | ส่วนใหญ่คำนวณบนเครื่อง — ถ้าต้องการราคาตามกลุ่มราคาจากเซิร์ฟเวอร์ให้ส่งนโยบายในแคตตาล็อก | `lib/features/pos/providers/cart_provider.dart` และโมเดล `lib/data/models/product.dart` |
| **ชำระเงิน + บันทึกบิล** | Push บิล (ดูรายละเอียดด้านล่าง) + idempotency `invoice_no` | `lib/features/pos/presentation/pos_screen.dart` (`_onCheckout`), `lib/core/sync/pos_sync_service.dart` (`persistCheckoutSale`, `tryPushPendingOrders`) |
| **เลขที่บิล / Device ID** | ไม่บังคับให้เซิร์ฟเวอร์ gen — แอป gen เอง offline | `lib/core/sync/invoice_number_generator.dart`, `lib/core/sync/device_identity.dart` |
| **SQLite offline** | ฝั่งลูกเก็บก่อน — ซิงค์ทีหลัง | `lib/core/database/app_database_io.dart`, `lib/core/database/database_schema.dart` |
| **ประวัติการขาย (บนเครื่อง)** | ถ้าต้องการรวมศูนย์: POST สำเนา `SaleRecord` หรือ sync จาก server | `lib/features/pos/data/sales_history_repository.dart`, `lib/features/pos/providers/sales_history_provider.dart`, `lib/features/pos/domain/sale_record.dart` |
| **หน้าประวัติ / ใบกำกับ / PDF** | ข้อมูลผู้ขาย + snapshot บิล — ถ้าต้องการเลข running จากกรมสรรหาการออก API แยก | `lib/core/utils/pdf_generator.dart`, `lib/core/utils/thermal_receipt_pdf.dart`, `lib/core/utils/tax_invoice_print.dart` |
| **ข้อมูลร้าน / พร้อมเพย์** | GET โปรไฟล์ร้าน (ชื่อ, ที่อยู่, เลขผู้เสียภาษี, PromptPay ID) | `lib/core/config/seller_profile.dart`, โหลดใน `lib/data/mock/mock_data_store.dart` (`_loadSeller` / `assets/mock/seller_profile.json`) |
| **ค้นหาสมาชิกจากเบอร์** | GET lookup ตามเบอร์ (10 หลัก) | `lib/features/pos/domain/pos_member_lookup.dart`, `lib/features/pos/providers/pos_session_provider.dart` (`PosMemberNotifier.searchByPhone`) |
| **สมัครสมาชิกใหม่** | POST สมาชิก | `lib/data/remote/member_registration.dart` (`registerMember`), UI ที่เรียกจาก `member_register_dialog.dart` (ถ้ามี) |
| **บิลพัก (Hold)** | ไม่ต้องมี API — เก็บเฉพาะเครื่อง | `lib/features/pos/providers/pos_session_provider.dart` (`heldBillProvider`) |
| **สต็อกคลัง / หน้า Inventory** | หน้า UI ยังว่าง — อาจใช้ endpoint สต็อกเดียวกับแคตตาล็อก | `lib/features/inventory/presentation/inventory_screen.dart`, `lib/features/inventory/providers/inventory_provider.dart` |

---

## 1. Authentication (พนักงาน)

**สถานะปัจจุบัน:** ตรวจ PIN กับ JSON ใน `assets/mock/employees_by_pin.json` ผ่าน `MockDataStore.employeeForPin`.

**Backend แนะนำ:**

- `POST /v1/auth/login`  
  - Body: `{ "pin": "123456" }` หรือ `{ "employee_code": "...", "pin": "..." }`  
  - Response: `{ "token": "...", "employee": { "id", "name", "role" } }`

**แอปต้องไปแตะ:**

- `lib/features/auth/providers/auth_provider.dart` — แทนที่ `_employeeForPin` ด้วยการเรียก API + เก็บ token (เช่น ผ่าน `SharedPreferences` หรือ `local_storage.dart` ที่จะ implement)

---

## 2. แคตตาล็อกสินค้า + สต็อก (Pull)

**สถานะปัจจุบัน:** `pullProductsOnStartup` อ่านจาก `MockDataStore` ลง SQLite

**Backend:** ตามรายละเอียดด้านล่าง (เหมือนเดิมสัญญา sync)

### `GET /v1/products?updated_after=<ms>`

- Response `products[]`: `id`, `barcode`, `name`, `price`, `stock_qty`, `updated_at` (ms epoch)

**แอปต้องไปแตะ:**

- `lib/core/sync/pos_sync_service.dart` — แทนที่ loop mock ด้วย `http.get` + parse JSON → `upsertProductRow`
- `lib/core/database/app_database_io.dart` — `upsertProductRow`, `setLastPullTimestamp`
- หน้าค้นหา: `lib/features/pos/presentation/product_search_dialog.dart` — อาจเปลี่ยนไปอ่านจาก DB แทนเมื่อพร้อม

---

## 3. Push บิลขาย (หลังชำระเงิน)

**สถานะปัจจุบัน:** บันทึก SQLite แล้ว `tryPushPendingOrders` ยังไม่ส่ง HTTP (รอ backend)

### `POST /v1/orders`

- Body ตาม JSON ด้านล่าง  
- Response **2xx** = สำเร็จ → แอปจะ `markOrderSynced`  
- **Idempotency:** `invoice_no` unique — ซ้ำให้ตอบ 2xx

```json
{
  "invoice_no": "DEVICE-260415-0001",
  "total_amount": 350.5,
  "payment_method": "cash",
  "device_id": "A1B2C3D4",
  "created_at": 1735689600000,
  "points_redeemed": 50,
  "items": [
    { "product_id": "prod-001", "qty": 2, "price": 50.25 }
  ]
}
```

- `total_amount` = ยอดที่ลูกค้าจ่ายจริง (หลังหักส่วนลดแลกแต้มแล้ว)
- `points_redeemed` = จำนวนแต้มที่แลกในบิลนี้ (0 ถ้าไม่ใช้) — ใช้หักแต้มในฐานข้อมูลหลัก

**แอปต้องไปแตะ:**

- `lib/core/sync/pos_sync_service.dart` — ใน `tryPushPendingOrders` ใส่ `POST` + `jsonEncode` (ใช้ `lib/data/remote/api_client.dart` แนะนำ)
- เพิ่ม header `Authorization` เมื่อมี token จาก login

---

## 4. ประวัติการขาย (SaleRecord — เก็บใน SharedPreferences)

**สถานะปัจจุบัน:** `SalesHistoryRepository` เก็บ JSON ในเครื่อง ไม่มี server

**Backend (ถ้าต้องการรวมศูนย์):**

- `POST /v1/sales` หรือ sync แบบเดียวกับ orders — โครงสร้างอ้างอิง `SaleRecord.toJson()` ใน `lib/features/pos/domain/sale_record.dart` (มี `lines`, VAT, ส่วนลด, สมาชิก, `tax_invoice_buyer`)

**แอปต้องไปแตะ:**

- `lib/features/pos/data/sales_history_repository.dart` — หลัง `append` อาจเรียก API  
- `lib/features/pos/providers/sales_history_provider.dart`

---

## 5. โปรไฟล์ร้าน (ใบกำกับ / PromptPay)

**สถานะปัจจุบัน:** `assets/mock/seller_profile.json` → `SellerProfile`

**Backend แนะนำ:**

- `GET /v1/store/profile` หรือรวมใน config หลัง login

**แอปต้องไปแตะ:**

- `lib/data/mock/mock_data_store.dart` (`_loadSeller`)  
- `lib/core/utils/pdf_generator.dart`, `lib/core/utils/thermal_receipt_pdf.dart` — ใช้ `MockDataStore.instance.sellerProfile`

---

## 6. สมาชิก — ค้นหา

**สถานะปัจจุบัน:** `assets/mock/members_by_phone.json`

**Backend แนะนำ:**

- `GET /v1/members?phone=0812345678`  
- Response: ชื่อ, ประเภท, แต้ม (ถ้ามี) — map เป็น `Member` / `MemberLookupHit`

**แอปต้องไปแตะ:**

- `lib/features/pos/domain/pos_member_lookup.dart`  
- `lib/features/pos/providers/pos_session_provider.dart` (`searchByPhone`)

---

## 7. สมาชิก — สมัครใหม่

**สถานะปัจจุบัน:** `registerMember` ใน `lib/data/remote/member_registration.dart` แค่ delay + `debugPrint`

**Backend แนะนำ:**

- `POST /v1/members` — body จาก `Member.toJson()` / ฟิลด์ที่ `apiValue` ของ `MemberType`

**แอปต้องไปแตะ:**

- `lib/data/remote/member_registration.dart`  
- ไดอะล็อกที่เรียกหลังสมัครสำเร็จ (เช่น `member_register_dialog.dart`)

---

## 8. ฟีเจอร์ที่ไม่ต้องมี API ตอนนี้

| ฟีเจอร์ | เหตุผล |
|---------|--------|
| บิลพัก (Hold) | เก็บใน memory/provider เท่านั้น |
| สร้างเลข PDF / ใบเสร็จ | คำนวณบนเครื่อง — ยกเว้นจะต้องอนุมัติเลขจากกรมสรรหาการแยก |
| Device ID / Running invoice | ออกแบบ offline ใน `device_identity.dart` / `invoice_number_generator.dart` |

---

## 9. อ้างอิงสคีมา SQLite ฝั่งลูก

ไฟล์: `lib/core/database/database_schema.dart`

- `products`, `orders` (รวม `points_redeemed`), `order_items`, `sync_status`

### คอนฟิกแลกแต้ม (ซิงค์)

- ตอนนี้ mock: `assets/mock/sync_config.json` มี `point_exchange_rate` — โหลดหลัง `MockDataStore.loadAll()` และหลัง `pullProductsOnStartup` สำเร็จ (`SyncConfigLoader.applyBundledMock`)
- เมื่อมี API จริง: แนะนำรวม `point_exchange_rate` ใน response ของ Pull หรือ endpoint `/v1/config` แล้วเรียก `AppConfig.setPointExchangeRateFromSync`

---

## 10. Checklist ตัวเองก่อน wire ครบ

- [ ] ใส่ `API_BASE_URL` ใน `.env`  
- [ ] Implement `api_client.dart` (base URL + auth header)  
- [ ] `pos_sync_service.dart`: Pull จริง + Push จริง + `markOrderSynced`  
- [ ] `auth_provider.dart`: login จริง + เก็บ token  
- [ ] (ถ้าต้องการ) `sales_history_repository.dart`: ส่งสำเนาบิลขึ้น server  
- [ ] (ถ้าต้องการ) โหลด `SellerProfile` จาก API แทน mock  
- [ ] `member_registration.dart` + `pos_member_lookup.dart`: ต่อ API สมาชิก  

---

*เอกสารนี้อธิบายสัญญา API เดิมจาก `docs/api_sync_contract.md` แล้วขยายให้ครอบคลุมทุกโมดูลที่เกี่ยวกับข้อมูลภายนอก — ถ้าต้องการรักษาไฟล์สั้นแยกเฉพาะ Pull/Push สามารถใช้ `api_sync_contract.md` เป็นส่วนย่อยได้*
