--поставщики
CREATE TABLE Suppliers(
  id int identity primary key,
  name nvarchar(50) not null
  );
--склады
create table Warehouses(
  id int identity primary key,
  name nvarchar(50) not null
  );
--категории товара
CREATE TABLE Categories(
  id int identity primary key,
  name nvarchar(50) not null
  );

--товары
CREATE TABLE Products(
  id int identity primary key,
  name nvarchar(50) not null,
  description nvarchar(250) not null,
  price money not null,
  category_id int REFERENCES Categories(id) on UPDATE cascade on DELETE cascade not null
  );
--закупки
CREATE table Procurement(
    id int identity primary key,
    product_id int REFERENCES Products(id) on UPDATE cascade on DELETE cascade not null,
    supplier_id int REFERENCES Suppliers(id) on UPDATE cascade on DELETE cascade not null,
    warehouses_id int REFERENCES Warehouses(id) on UPDATE cascade on DELETE cascade not null default 1,
  amount int not null,
    dateofreceipt date not null default getdate()
  );
--товары на складах (в наличии)
CREATE table ProductsInStock(
    id int identity primary key,
    product_id int REFERENCES Products(id) on UPDATE cascade on DELETE cascade not null,
   warehouses_id int REFERENCES Warehouses(id) on UPDATE cascade on DELETE cascade not null default 1,
  amount int not null
  );
--продажи
CREATE table Sales(
    id int identity primary key,
    product_id int REFERENCES Products(id) on UPDATE cascade on DELETE cascade not null,
  amount int not null,
    dateofsales date not null default getdate()
  );


--создание закупки(заполнение данных как и во всех процедурах)
CREATE procedure ProcurementInsert
    @product_id int,
    @supplier_id int,
    @amount int,
    @warehouses_id int
    AS
    INSERT into Procurement(product_id, supplier_id, amount, warehouses_id) VALUES (@product_id, @supplier_id, @amount, @warehouses_id);

-- создание поставщика
create procedure SupplierCreate
   @name nvarchar(50)
     as
    INSERT into Suppliers(name) VALUES (@name);
-- создание категории
create procedure CategorieCreate
   @name nvarchar(50)
     as
    INSERT into Categories(name) VALUES (@name);
-- создание товара
create procedure ProductCreate
  @name nvarchar(50),
    @description nvarchar(250),
    @price money,
    @category_id int
    AS
    INSERT into Products(name, description, price, category_id) VALUES (@name, @description, @price, @category_id);
-- создание продажи
create procedure SaleCreate
  @product_id int,
    @amount int
    AS
    INSERT into Sales(product_id, amount) VALUES (@product_id, @amount);
-- создание склада
create procedure WarehousesCreate
   @name nvarchar(50)
     as
    INSERT into Warehouses(name) VALUES (@name);
-- событие срабатывающее при закупке : товары заносятся в таблицу "товары в наличии"  или изменяется их количество
create TRIGGER ProductsReceipt
  on Procurement
    After insert
    AS
    BEGIN
      DECLARE @id int, @amount int;
        set @id = (select top 1 product_id from Procurement ORDER by id desc);
        set @amount = (select top 1 amount from Procurement ORDER by id desc);
        if EXISTS (select product_id from ProductsInStock where product_id = @id)
          update ProductsInStock
          set amount = amount + @amount
          WHERE product_id = @id;
        else
          BEGIN
              DECLARE @warehouses_id int;
              SEt @warehouses_id = (select top 1 warehouses_id from Procurement ORDER by id desc);
              INSERT into ProductsInStock(product_id, amount, warehouses_id) VALUES (@id, @amount, @warehouses_id);
            END;
    end;

-- событие срабатывающее при продаже: изменяется колво товара на складе, если остатки становятся нулевыми откатывается обратно
create TRIGGER ProductsSale
  on Sales
    After insert
    AS
    BEGIN
      DECLARE @id int, @amount int;
        set @id = (select top 1 product_id from Sales ORDER by id desc);
        set @amount = (select top 1 amount from Sales ORDER by id desc);
        BEGIN Transaction
          update ProductsInStock
          set amount = amount - @amount
          WHERE product_id = @id;
       if @amount > (select amount from ProductsInStock where product_id = @id)
          Rollback Transaction;
        Else
          commit Transaction;
    end;

  — временная таблица (представление) хранящая в себе
CREATE view ProfitCompany as
  SELECT sum(amount * Products.price) as profit
  from Sales
  join Products on Sales.product_id = Products.id;