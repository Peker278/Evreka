USE [Evreka]
GO

/****** Object:  View [dbo].[durationAndDistance]    Script Date: 30.10.2024 00:05:53 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER VIEW [dbo].[durationAndDistance] AS 


-- Records with distance attribute is zero and with recorded_at attribute is first date was detected.
with includedZero as ( 
select a.route_id,a.distance,a.recorded_at,MIN(b.recorded_at) min_tarih,
case when MIN(b.recorded_at) = a.recorded_at then 1 else 0 end as toremoving
from 
(select route_id,MIN(distance) distance,recorded_at
from Navigation_Records where distance = 0.00 group by route_id,recorded_at ) a left join Navigation_Records b on a.route_id = b.route_id 
group by a.route_id,a.distance,a.recorded_at ),

-- Records with distance attribute is zero and with recorded_at attribute is first date was filtered.
onlyfirstzerovalue as (
select nvg.route_id,nvg.distance,nvg.recorded_at,iz.toremoving
from Navigation_Records nvg left join includedZero iz 
on nvg.route_id = iz.route_id and nvg.distance = iz.distance and nvg.recorded_at = iz.recorded_at
where iz.toremoving = 1 or iz.toremoving is null) ,

-- Duplicate records according to route_id and distance was detected.
DetectingDuplicates as ( 
select *,row_number() over(partition by route_id,distance order by recorded_at) #rownumber
from onlyfirstzerovalue ) ,

-- Duplicate records according to route_id and distance was deleted. 
RemovingDuplicates as ( 

select *,
LEAD(distance) over(partition by route_id order by recorded_at) as next_value,
LAG (distance) over(partition by route_id order by recorded_at) as previous_value from DetectingDuplicates where #rownumber = 1 ) ,

-- Unlogic records was detected.

DetectingAmbigous as (

select *,
case when next_value>distance then 1 else 0 end as control_next,
case when previous_value<distance then 1 else 0 end as control_previous,
isnull(next_value,-990000) next_, isnull(previous_value,-990000) pre_

from RemovingDuplicates ) ,

-- Route's total duration was figured out.
duration_template as (
select route_id, MAX(recorded_at) max_date,MIN(recorded_at) min_date,
DATEDIFF(SECOND,MIN(recorded_at),MAX(recorded_at)) / 3600 hourr,
(DATEDIFF(SECOND,MIN(recorded_at),MAX(recorded_at)) %3600) / 60  minutee,
((DATEDIFF(SECOND,MIN(recorded_at),MAX(recorded_at)) %3600) % 60) secondd

from DetectingAmbigous
where previous_value is null or  next_value is null group by route_id),

-- Total duration data format was fixed.
duration_last as ( 
select *,
CONCAT(hourr,':',minutee,':',secondd) duration from duration_template ),

-- Records in order to calculate total distance by route was detected.
distance_template as (
select route_id, distance, next_-distance as pr, distance-previous_value as tr,next_value,previous_value from DetectingAmbigous   
where (previous_value is not null or next_value is not null) and (control_next = 0 or control_previous = 0)),

-- By doing to filter according to certain criters necessary records was calculated.
distance_last as (
select route_id,SUM(distance) total_distance from distance_template where (pr<-80 or tr<-80) and pr <> 1.08 group by route_id ),

-- Table comprising route_id, total_distance and duration column was created.
final_table as ( 
select dil.route_id,dil.total_distance,dul.duration from distance_last dil left join duration_last dul on dil.route_id = dul.route_id ) 

-- Relevant data was showed.
select * from final_table 

GO


