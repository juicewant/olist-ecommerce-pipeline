select cast(d as date) as date_day
from generate_series(
    date '2016-09-01', date '2018-12-31', interval 1 day
) as t(d)