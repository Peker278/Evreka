create database Evreka

use Evreka

-- proper table was created regard as dataset
create table Navigation_Records ( 
route_id varchar(10),
recorded_at datetime,
distance numeric(17,2)

) 

-- insert transaction could do with ETL tool surely. I prefered to do on local machine.
go
BULK INSERT	dbo.Navigation_Records 
from 'C:\Users\LENOVO\Desktop\navigation_records.csv' 
with (
FIRSTROW = 2,
FIELDTERMINATOR = ',',
ROWTERMINATOR = '0x0a',
FORMAT = 'CSV'
)
go


