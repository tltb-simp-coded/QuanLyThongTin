# 🏥 Hệ Thống Quản Lý Bệnh Viện

> **Môn học:** IE103.Q22 — Quản lý Thông tin
> **Trường:** Trường Đại học Công nghệ Thông tin — ĐHQG TP.HCM

---

## 👥 Thành Viên Nhóm 36

| Họ tên | MSSV | Nhiệm vụ |
|---|---|---|
| Trần Lê Thiên Bảo | ... | Stored Procedure · Function · Flask App · Video demo |
| Lê Trí Cao | ... | Mô tả bài toán · Lược đồ quan hệ · Tổng hợp báo cáo |
| Dương Lê | ... | ERD diagram · CREATE TABLE · Triggers · Backup & Restore |
| Huỳnh Cao Mẫn Duy | ... | INSERT scripts mẫu · Import/Export |
| Tô Ngọc Huy | ... | Cursor SQL · Phân quyền (LOGIN/USER/ROLE/GRANT/DENY) |

---

## 📋 Giới Thiệu

Hệ thống quản lý bệnh viện được xây dựng trên **SQL Server** và **Flask (Python)**, hỗ trợ toàn bộ quy trình từ tiếp nhận bệnh nhân đến xuất hóa đơn thanh toán.

### Cơ sở dữ liệu (SQL Server)

- **10 bảng:** `BenhNhan`, `BacSi`, `NhanVien`, `Thuoc`, `LichHen`, `HoSoBenhAn`, `DonThuoc`, `ChiTietDonThuoc`, `XetNghiem`, `HoaDon`
- **3 Stored Procedure:** `sp_TiepNhanBenhMoi`, `sp_KeDonThuoc`, `sp_XuatHoaDon`
- **2 Function:** `fn_TinhTongTienHoaDon`, `fn_KiemTraLichTrong`
- **4 Trigger:** kiểm tra ngày khám, hạn dùng thuốc, đóng HSBA, quyền kê đơn

### Web App (Flask)

| Route | Chức năng |
|---|---|
| `/` | Dashboard — thống kê tổng quan |
| `/tiep-nhan` | Tiếp nhận bệnh nhân mới/cũ qua CCCD |
| `/lich-hen` | Danh sách lịch hẹn theo ngày |
| `/kham-benh/<MaLich>` | Ghi hồ sơ bệnh án |
| `/ke-don/<MaHoSo>` | Kê đơn thuốc (chỉ Bác sĩ) |
| `/hoa-don/<MaHoSo>` | Xuất & xác nhận thanh toán |
| `/bao-cao` | Báo cáo doanh thu tháng |

---

## ⚙️ Yêu Cầu Cài Đặt

| Phần mềm | Phiên bản |
|---|---|
| Python | 3.13+ |
| SQL Server | 2019+ (Express edition là đủ) |
| SSMS | Bất kỳ |
| ODBC Driver 17 for SQL Server | [Tải tại đây](https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server) |

---

## 🚀 Hướng Dẫn Cài Đặt

### Bước 1 — Clone repo

```bash
git clone https://github.com/tltb-simp-coded/QuanLyThongTin.git
cd QuanLyThongTin
```

### Bước 2 — Tạo Database (chỉ làm 1 lần)

Mở **SSMS**, chạy lần lượt 2 file SQL ở thư mục gốc:

```
01_Create_Database.sql   ← Tạo database QuanLyBenhVien + 10 bảng + 4 Trigger
02_SP_Functions.sql      ← Tạo 3 Stored Procedure + 2 Function
```

### Bước 3 — Đặt file dữ liệu mẫu

Đảm bảo file `Data_PhongKham.xlsx` nằm tại:
```
D:\IE103\Data_PhongKham.xlsx
```
*(hoặc chỉnh đường dẫn trong `04_Import_Excel.py`)*

### Bước 4 — Chạy ứng dụng

**Cách nhanh nhất** — double-click:
```
QuanLyBenhVien\start.bat
```

File này tự động cài thư viện, import data và mở `http://localhost:5000`.

**Hoặc chạy thủ công:**
```bash
cd QuanLyBenhVien
py -3.13 -m pip install flask pyodbc openpyxl
py -3.13 04_Import_Excel.py
py -3.13 app.py
```

---

## 🔑 Tài Khoản Demo

| Tài khoản | Mật khẩu | Vai trò | Quyền đặc biệt |
|---|---|---|---|
| `bacsi` | `123456` | Bác sĩ | **Kê đơn thuốc** |
| `nv01` | `123456aA@` | Admin | Quản lý hệ thống |
| `nv02` | `123456aA@` | Y tá | Tiếp nhận, lịch hẹn |
| `nv05` | `123456aA@` | Kế toán | Xuất hóa đơn |

> Chỉ tài khoản **Bác sĩ** mới được truy cập trang `/ke-don`.

---

## 🗂️ Cấu Trúc Thư Mục

```
QuanLyThongTin/
├── 01_Create_Database.sql      ← Schema + Triggers
├── 02_SP_Functions.sql         ← SP + Functions
├── Data_PhongKham.xlsx         ← Dữ liệu mẫu
└── QuanLyBenhVien/
    ├── app.py                  ← Flask routes
    ├── db.py                   ← Kết nối SQL Server
    ├── start.bat               ← Khởi động nhanh
    ├── 04_Import_Excel.py      ← Import dữ liệu mẫu
    ├── templates/              ← Jinja2 HTML templates
    └── static/style.css        ← CSS (Bootstrap 5 + Inter)
```

---

## 🔄 Luồng Demo (5 phút)

```
Đăng nhập bacsi
    ↓
Dashboard → xem lịch hẹn hôm nay
    ↓
Lịch Hẹn → bấm [Bắt đầu khám]
    ↓
Khám Bệnh → điền chẩn đoán → [Lưu & Chuyển Kê Đơn]
    ↓
Kê Đơn → chọn thuốc từ danh mục → [Hoàn Tất Kê Đơn]
    ↓
Hóa Đơn → [Xuất Hóa Đơn] → [Xác Nhận Đã Thanh Toán]
    ↓
Báo Cáo → xem doanh thu tháng
```

---

## 🛠️ Xử Lý Sự Cố

**Lỗi kết nối SQL Server:**
- Kiểm tra service đang chạy: `services.msc` → SQL Server (MSSQLSERVER)
- Đổi `SERVER=localhost` thành tên máy trong `db.py` nếu cần

**Lỗi ODBC Driver không tìm thấy:**
- Tải và cài: [ODBC Driver 17 for SQL Server](https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server)

**Import Excel thất bại:**
- Kiểm tra file `Data_PhongKham.xlsx` đúng vị trí
- Đảm bảo đã chạy `01_Create_Database.sql` trước

**Port 5000 bị chiếm:**
- Đổi port trong `app.py` dòng cuối: `app.run(debug=True, port=5001)`
