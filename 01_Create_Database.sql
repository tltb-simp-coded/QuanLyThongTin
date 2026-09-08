-- ============================================================
-- FILE    : 01_Create_Database.sql
-- MÔN     : IE103 - Quản lý Thông tin
-- ĐỀ TÀI : Hệ thống Quản lý Bệnh viện
-- PHẦN    : Tạo CSDL + Bảng + Triggers
-- THỰC HIỆN: Nhóm (Dương Lê + Trần Lê Thiên Bảo)
--
-- HƯỚNG DẪN CHẠY:
--   Bước 1: Mở SSMS, kết nối vào SQL Server
--   Bước 2: Mở file này, nhấn F5 (hoặc Execute) để chạy toàn bộ
--   Bước 3: Sau khi xong, mở file 02_SP_Functions.sql và chạy tiếp
-- ============================================================


-- ============================================================
-- BƯỚC 1: TẠO CƠ SỞ DỮ LIỆU
-- ============================================================

-- Nếu CSDL đã tồn tại thì xóa và tạo lại (tiện khi reset để test)
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'QuanLyBenhVien')
BEGIN
    ALTER DATABASE QuanLyBenhVien SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE QuanLyBenhVien;
    PRINT N'Đã xóa CSDL cũ: QuanLyBenhVien';
END
GO

CREATE DATABASE QuanLyBenhVien;
GO

PRINT N'Đã tạo CSDL: QuanLyBenhVien';
GO

-- Chuyển ngữ cảnh làm việc vào CSDL vừa tạo
USE QuanLyBenhVien;
GO


-- ============================================================
-- BƯỚC 2: TẠO CÁC BẢNG
-- Thứ tự quan trọng: bảng cha phải tạo trước bảng con (FK)
--
--  Không có FK:  BenhNhan, BacSi, NhanVien, Thuoc
--  FK cấp 1  :  LichHen, HoSoBenhAn
--  FK cấp 2  :  DonThuoc, XetNghiem, HoaDon
--  FK cấp 3  :  ChiTietDonThuoc
-- ============================================================

-- ----------------------------------------------------------
-- Bảng 1: BenhNhan
-- Lưu thông tin định danh và y tế cơ bản của bệnh nhân
-- ----------------------------------------------------------
CREATE TABLE BenhNhan (
    MaBN        VARCHAR(20)    PRIMARY KEY,
    HoTen       NVARCHAR(100)  NOT NULL,
    NgaySinh    DATE           NOT NULL,
    GioiTinh    NVARCHAR(10)   CHECK (GioiTinh IN (N'Nam', N'Nữ', N'Khác')),
    CCCD        VARCHAR(20)    UNIQUE NOT NULL,
    DiaChi      NVARCHAR(255),
    SDT         VARCHAR(15),
    NhomMau     VARCHAR(5),
    TienSuBenh  NVARCHAR(MAX)
);
GO

-- ----------------------------------------------------------
-- Bảng 2: BacSi
-- Lưu thông tin chuyên môn của bác sĩ
-- ----------------------------------------------------------
CREATE TABLE BacSi (
    MaBS        VARCHAR(20)    PRIMARY KEY,
    HoTen       NVARCHAR(100)  NOT NULL,
    ChuyenKhoa  NVARCHAR(100),
    SDT         VARCHAR(15),
    Email       VARCHAR(100),
    TrinhDo     NVARCHAR(50)
);
GO

-- ----------------------------------------------------------
-- Bảng 3: NhanVien
-- Lưu tài khoản hệ thống: Admin, Bác sĩ, Y tá, Kế toán
-- ----------------------------------------------------------
CREATE TABLE NhanVien (
    MaNV        VARCHAR(20)    PRIMARY KEY,
    HoTen       NVARCHAR(100)  NOT NULL,
    VaiTro      NVARCHAR(50)   NOT NULL
                               CHECK (VaiTro IN (N'Admin', N'Bác sĩ', N'Y tá', N'Kế toán')),
    TaiKhoan    VARCHAR(50)    UNIQUE NOT NULL,
    MatKhau     VARCHAR(255)   NOT NULL
);
GO

-- ----------------------------------------------------------
-- Bảng 4: Thuoc
-- Danh mục thuốc: giá bán, tồn kho, hạn sử dụng
-- ----------------------------------------------------------
CREATE TABLE Thuoc (
    MaThuoc     VARCHAR(20)    PRIMARY KEY,
    TenThuoc    NVARCHAR(100)  NOT NULL,
    DonVi       NVARCHAR(20),
    GiaBan      DECIMAL(18,2)  CHECK (GiaBan > 0),
    SoLuongTon  INT            CHECK (SoLuongTon >= 0),
    HanSuDung   DATE           NOT NULL
);
GO

-- ----------------------------------------------------------
-- Bảng 5: LichHen
-- Quản lý lịch hẹn khám giữa bệnh nhân và bác sĩ
-- FK: BenhNhan, BacSi
-- ----------------------------------------------------------
CREATE TABLE LichHen (
    MaLich      VARCHAR(20)    PRIMARY KEY,
    MaBN        VARCHAR(20)    NOT NULL REFERENCES BenhNhan(MaBN),
    MaBS        VARCHAR(20)    NOT NULL REFERENCES BacSi(MaBS),
    NgayGio     DATETIME       NOT NULL,
    LyDoKham    NVARCHAR(255),
    TrangThai   NVARCHAR(50)   DEFAULT N'Chờ khám'
);
GO

-- ----------------------------------------------------------
-- Bảng 6: HoSoBenhAn
-- Trung tâm dữ liệu của mỗi lần khám: chẩn đoán, triệu chứng
-- FK: BenhNhan, BacSi
-- ----------------------------------------------------------
CREATE TABLE HoSoBenhAn (
    MaHoSo      VARCHAR(20)    PRIMARY KEY,
    MaBN        VARCHAR(20)    NOT NULL REFERENCES BenhNhan(MaBN),
    MaBS        VARCHAR(20)    NOT NULL REFERENCES BacSi(MaBS),
    NgayKham    DATETIME       NOT NULL,
    ChanDoan    NVARCHAR(MAX),
    TrieuChung  NVARCHAR(MAX),
    GhiChu      NVARCHAR(MAX),
    TrangThai   NVARCHAR(50)   DEFAULT N'Đang xử lý'
);
GO

-- ----------------------------------------------------------
-- Bảng 7: DonThuoc
-- Đơn thuốc gắn với một hồ sơ bệnh án (quan hệ 1-1)
-- FK: HoSoBenhAn (CASCADE DELETE), NhanVien
-- ----------------------------------------------------------
CREATE TABLE DonThuoc (
    MaDon           VARCHAR(20)    PRIMARY KEY,
    MaHoSo          VARCHAR(20)    UNIQUE NOT NULL
                                   REFERENCES HoSoBenhAn(MaHoSo) ON DELETE CASCADE,
    MaNV_KeDon      VARCHAR(20)    NOT NULL REFERENCES NhanVien(MaNV),
    NgayKe          DATETIME       DEFAULT GETDATE(),
    HuongDanSuDung  NVARCHAR(MAX)
);
GO

-- ----------------------------------------------------------
-- Bảng 8: ChiTietDonThuoc
-- Bảng trung gian N-N giữa DonThuoc và Thuoc
-- FK: DonThuoc (CASCADE DELETE), Thuoc
-- ----------------------------------------------------------
CREATE TABLE ChiTietDonThuoc (
    MaDon       VARCHAR(20)    NOT NULL REFERENCES DonThuoc(MaDon) ON DELETE CASCADE,
    MaThuoc     VARCHAR(20)    NOT NULL REFERENCES Thuoc(MaThuoc),
    SoLuong     INT            CHECK (SoLuong > 0),
    LieuDung    NVARCHAR(100),
    TanSuat     NVARCHAR(100),
    PRIMARY KEY (MaDon, MaThuoc)
);
GO

-- ----------------------------------------------------------
-- Bảng 9: XetNghiem
-- Các xét nghiệm được chỉ định trong một hồ sơ bệnh án
-- FK: HoSoBenhAn (CASCADE DELETE)
-- ----------------------------------------------------------
CREATE TABLE XetNghiem (
    MaXN            VARCHAR(20)    PRIMARY KEY,
    MaHoSo          VARCHAR(20)    NOT NULL
                                   REFERENCES HoSoBenhAn(MaHoSo) ON DELETE CASCADE,
    LoaiXN          NVARCHAR(100),
    KetQua          NVARCHAR(MAX),
    NgayThucHien    DATETIME
);
GO

-- ----------------------------------------------------------
-- Bảng 10: HoaDon
-- Hóa đơn thanh toán viện phí sau khi khám xong
-- FK: BenhNhan, HoSoBenhAn
-- ----------------------------------------------------------
CREATE TABLE HoaDon (
    MaHD        VARCHAR(20)    PRIMARY KEY,
    MaBN        VARCHAR(20)    NOT NULL REFERENCES BenhNhan(MaBN),
    MaHoSo      VARCHAR(20)    UNIQUE NOT NULL REFERENCES HoSoBenhAn(MaHoSo),
    NgayLap     DATETIME       DEFAULT GETDATE(),
    TongTien    DECIMAL(18,2)  DEFAULT 0,
    TrangThaiTT NVARCHAR(50)   DEFAULT N'Chưa thanh toán'
);
GO

PRINT N'Đã tạo xong 10 bảng.';
GO


-- ============================================================
-- BƯỚC 3: TẠO TRIGGERS (Ràng buộc nghiệp vụ)
-- ============================================================

-- ----------------------------------------------------------
-- Trigger 1: Ngày khám phải >= Ngày sinh bệnh nhân
-- ----------------------------------------------------------
CREATE TRIGGER trg_Check_NgayKham
ON HoSoBenhAn
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN BenhNhan bn ON i.MaBN = bn.MaBN
        WHERE CAST(i.NgayKham AS DATE) < bn.NgaySinh
    )
    BEGIN
        RAISERROR(N'Lỗi: Ngày khám không được nhỏ hơn ngày sinh của bệnh nhân!', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- ----------------------------------------------------------
-- Trigger 2: Thuốc kê đơn phải còn hạn sử dụng
-- ----------------------------------------------------------
CREATE TRIGGER trg_Check_HanSuDung_Thuoc
ON ChiTietDonThuoc
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Thuoc    t  ON i.MaThuoc = t.MaThuoc
        JOIN DonThuoc dt ON i.MaDon   = dt.MaDon
        WHERE t.HanSuDung <= CAST(dt.NgayKe AS DATE)
    )
    BEGIN
        RAISERROR(N'Lỗi: Thuốc được chỉ định đã hết hạn sử dụng so với ngày kê đơn!', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- ----------------------------------------------------------
-- Trigger 3: Chỉ được đóng HSBA khi hóa đơn đã thanh toán
-- ----------------------------------------------------------
CREATE TRIGGER trg_Check_Dong_HSBA
ON HoSoBenhAn
AFTER UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN HoaDon hd ON i.MaHoSo = hd.MaHoSo
        WHERE i.TrangThai = N'Hoàn thành'
          AND hd.TrangThaiTT <> N'Đã thanh toán'
    )
    BEGIN
        RAISERROR(N'Lỗi: Không thể hoàn thành HSBA vì hóa đơn chưa được thanh toán!', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- ----------------------------------------------------------
-- Trigger 4: Chỉ nhân viên có vai trò "Bác sĩ" được kê đơn
-- ----------------------------------------------------------
CREATE TRIGGER trg_Check_Quyen_KeDon
ON DonThuoc
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN NhanVien nv ON i.MaNV_KeDon = nv.MaNV
        WHERE nv.VaiTro <> N'Bác sĩ'
    )
    BEGIN
        RAISERROR(N'Lỗi: Chỉ nhân viên có vai trò "Bác sĩ" mới được phép kê đơn thuốc!', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

PRINT N'Đã tạo xong 4 Triggers.';
PRINT N'';
PRINT N'>>> Tiếp theo: Mở file 02_SP_Functions.sql và chạy để tạo SP + Function.';
GO
