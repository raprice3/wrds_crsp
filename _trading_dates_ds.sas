/*
* Macro: trading_dates_ds
* Written by Richard Price
* May 13, 2013

* Note, there is another macro trading_datess which is much less efficient

* This macro creates a dataset with every calendar day and has a date
* corresponding to the market open.  If the market is open on that date
* then the calendar date is equal to the market open date.  If not, then
* the market open date is the next date corresponding to when the market was
* open.

* Simply incrementing dates by weekday does not always work because
* the market is closed on holidays and other events (death of president).
* The market was closed the entire week of 9/11.

* Input parameters;
* min_year:    the minimum year you need, default is 1925 
*              (increasing min_year to what you need is more efficient)
* max_year:    the maximum year you need, default is 2100
* dsout:       name of output dataset, default is work.trading_dates

* OUTPUT:
* The macro outputs a dataset containing the following:
* caldt:       the calendar date
* mkt_open:    indicator of whether market was open that day
* mktdt:       equals caldt if mkt_open=1, 
*              equals next date market was open if mkt_open=0
* reldate:     a counter with each integer corresponding to 
*              days the market was open
* reldate_pvs: a counter with each integer corresponding to
*              days the market was open.  If a date falls
*              on a date in which the market is closed, it
*              links to the most recent date the market was open

  Obs       caldt    mkt_open        mktdt    reldate    lag

    1    19251231        1       31DEC1925         1       .
    2    19260101        0       02JAN1926         2       2
    3    19260102        1       02JAN1926         2       2
    4    19260103        0       04JAN1926         3       2
    5    19260104        1       04JAN1926         3       2
    6    19260105        1       05JAN1926         4       1
    7    19260106        1       06JAN1926         5       1
    8    19260107        1       07JAN1926         6       1
    9    19260108        1       08JAN1926         7       1
   10    19260109        1       09JAN1926         8       1
   11    19260110        0       11JAN1926         9       2
   12    19260111        1       11JAN1926         9       2
   13    19260112        1       12JAN1926        10       1
   14    19260113        1       13JAN1926        11       1
   15    19260114        1       14JAN1926        12       1
...
9/11

27647    20010909        0       10SEP2001     20188       3
27648    20010910        1       10SEP2001     20188       3
27649    20010911        0       17SEP2001     20189       7
27650    20010912        0       17SEP2001     20189       7
27651    20010913        0       17SEP2001     20189       7
27652    20010914        0       17SEP2001     20189       7
27653    20010915        0       17SEP2001     20189       7
27654    20010916        0       17SEP2001     20189       7
27655    20010917        1       17SEP2001     20189       7
...
Death of President Ford, markets closed on Jan 02, 2007

29583    20061228        1       28DEC2006     21520       1
29584    20061229        1       29DEC2006     21521       1
29585    20061230        0       03JAN2007     21522       5
29586    20061231        0       03JAN2007     21522       5
29587    20070101        0       03JAN2007     21522       5
29588    20070102        0       03JAN2007     21522       5
29589    20070103        1       03JAN2007     21522       5
29590    20070104        1       04JAN2007     21523       1
29591    20070105        1       05JAN2007     21524       1
29592    20070106        0       08JAN2007     21525       3
29593    20070107        0       08JAN2007     21525       3
29594    20070108        1       08JAN2007     21525       3
29595    20070109        1       09JAN2007     21526       1
29596    20070110        1       10JAN2007     21527       1


* example of usage:

To use this macro, merge reldate with your dataset to ensure your
date corresponds to a date the market was open.  Then for your 
desired window, merge other relative dates and then the returns
for your needed window.

%trading_dates_ds(min_year=1998);

data ds;
    set Your_DS;
run;

* if your identifier is CIK;
proc sql;
    create table ds as
        select a.*, b.gvkey, b.cusip
        from ds a left join comp.names b
	on a.cik=b.cik;

* if your identifier is gvkey;
* use the dataset created with the mycstlink macro;
proc sql;
    create table ds as
	select a.*, b.lpermno as permno
	from ds a left join home.mycstlink b
	on a.gvkey=b.gvkey and not missing(a.gvkey) and
	b.linkdt le a.date le b.extlinkenddt;

* if your identifier is cusip;
* use the link_permno_cusip macro;    
proc sql;
    create table ds as
	select a.*, b.permno as permno2
	from ds a left join home.cusip_small b
	on substr(a.cusip,1,8)=b.ncusip and b.beg le a.date le b.end;

* merge returns;

proc sql; ** merge relative trading dates;
    create table ds as
	select a.*, b.reldate
	from ds a left join trading_dates b
	on a.date = b.caldt;

* a simple macro to iterate the merge;
%macro iter(n,suf);

    proc sql; ** merge relative trading dates;
	create table x as
	    select a.*, b.reldate-a.reldate as day, b.mktdt	
	    from ds a left join mkt_open b
	    on b.reldate-a.reldate = &n 
	    order by permno, mktdt;

    proc sql; ** merge returns, create several small datasets for efficiency;
	create table dsret&suf as
	    select x.*, b.ret, b.vol
	    from x left join crsp.dsf b
	    on x.mktdt=b.date and x.permno=b.permno
	    order by permno, mktdt, accession_number;

%mend;

%iter(-10,m10);%iter(-9,m9);%iter(-8,m8);%iter(-7,m7);%iter(-6,m6);%iter(-5,m5);%iter(-4,m4);%iter(-3,m3);%iter(-2,m2);%iter(-1,m1);
%iter(0,p0);
%iter(10,p10);%iter(9,p9);%iter(8,p8);%iter(7,p7);%iter(6,p6);%iter(5,p5);%iter(4,p4);%iter(3,p3);%iter(2,p2);%iter(1,p1);

* instead of doing the merge day by day, could simply merge day -10 to day 10 and then merge all returns within that window;

*/

%macro trading_dates_ds(min_year=1925,max_year=2100,dsout=work.trading_dates);

* Step 1, create a dataset of all dates the market was open;

proc sql;
    create table mkt_open as
	select distinct date, 1 as mkt_open from crsp.dsi order by date;

* Step 2, number each day the market was open (reldate);
* this allows, when computing intervals, to identify the date n days away from a particular date;

data mkt_open;
    set mkt_open;
    mktdt=date;
    format mktdt date9.;
    mkt_open=1;
    reldate=_n_;
    if year(date) < &min_year then delete;
    if year(date) > &max_year then delete;
run;

* Step 3, create a dataset with all calendar days, and (for dates when market is not open) the;
* corresponding next market date;

data trading_dates;
    set mkt_open;
    lag=date-lag(date);
run;

proc sql;
    select max(lag) into: max_lag from trading_dates;

* Fill in holes;
    data holes;
	set trading_dates;
	if lag > 1;
	drop mkt_open;
    run;

    %do n=1 %to &max_lag;    
	data hole_i;
	    set holes;
	    mkt_open=0;
	    date=intnx('day',date,-&n);
	run;

	data trading_dates;
	    set trading_dates hole_i;
	run;
	
	data holes;
	    set holes;
	    if lag > &n+1;
	run;
	
    %end;

    data trading_dates;
	set trading_dates;
	reldate_pvs = reldate;
	if mkt_open=0 then reldate_pvs=reldate-1;
    run;

proc sort in=trading_dates out=&dsout;
    by date;
run;

%mend;
