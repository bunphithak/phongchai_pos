# สัญญา API Pull/Push (ย่อ)

รายละเอียดเต็มทุกฟีเจอร์ + แผนที่ไฟล์ Flutter อยู่ที่:

**[backend_integration_guide.md](backend_integration_guide.md)**

---

## Pull — `GET /v1/products?updated_after=<ms>`

- Response `products[]`: `id`, `barcode`, `name`, `price`, `stock_qty`, `updated_at` (ms epoch)

## Push — `POST /v1/orders`

- **Idempotency:** `invoice_no` unique — ซ้ำให้ตอบ **2xx**
- **`payment_method`:** ต้องรองรับอย่างน้อย `cash` | `transfer` | `mixed`  
  - แอปแบ่งยอดเงินสด / โอนในหน้าชำระเงิน — ถ้าต้องการกระทบยอด PromptPay / บัญชี แนะนำรับเพิ่ม `cash_amount`, `transfer_amount`, `change_amount` (ดูคู่มือเต็ม)
- **`total_amount`:** ยอดที่ลูกค้าจ่ายจริง (หลังหักส่วนลดแลกแต้มแล้ว)

## ยกเลิกบิล (แนะนำเมื่อรวมศูนย์)

- แอปเก็บ `is_voided`, เหตุผล, ผู้ void ใน SQLite แล้ว — ฝั่งเซิร์ฟเวอร์แนะนำ endpoint แยก (เช่น `POST /v1/orders/{invoice_no}/void`) — รายละเอียดใน **backend_integration_guide.md**

## หน้า Inventory / สต็อก

- อ่านสต็อกจากชุดเดียวกับแคตตาล็อก (Pull) — หน้า `Inventory` ในแอปแสดงจากข้อมูลเดียวกับ mock/DB หลังซิงค์
