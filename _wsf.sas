/*
*** Macro wsf.sas
*** Created by Richard Price
*** March 28, 2012

This macro computes a weekly stock file, similar to the monthly and daily 
stock files provided by CRSP.  The measurement date selected is Friday, but
can easily be changed if desired.

Because the weekly dataset is based on the daily dataset, the units of measurement
corresponding to the daily file also pertain to the weekly dataset.  In particular
volume is measured in the daily dataset in actual number of shares.  But in the 
monthly dataset, it is in units of 100 shares.
http://www.crsp.com/support/glossary.html

Note that prior to 1953, the market was open on Saturdays.  However for consistency
with the post 1952 period, Friday is used (by default) to measure returns for the early years.
    proc sql;
        select distinct year(date) as year, weekday(date) as weekday from crsp.dsf

Input Parameters:

outlib:      (default outlib=work)
             the name of the output library.

Specify when to begin the return accumulation:

begweek1:    (default begweek1='02jan1926'd) (This is a Saturday)
             the beginning date following the format shown above.

endweek1:    (default endweek1='08jan1926'd) (This is a Friday)
             the ending date following the format shown above.

	     The default values produce returns as of Friday for the entire CRSP history.

	     Other options include 
	     Monday, January 4, 1960
	     Friday, January 8, 1960.

	     Or you could do Monday to Saturday (post 1953 this would produce Monday-Friday returns)
	     Monday, January 4, 1926
	     Saturday, January 9, 1926

Output:

The file creates weekly stock file (wsf) and a corresponding event file (only for delistings) wse.

*/

%macro wsf(begweek1='02jan1926'd,endweek1='08jan1926'd,outlib=work);

%* determine the number of weeks the macro needs to compute returns for;
%* It is assumed that returns need to be computed to the latest possible date;
%* numweeks is likely to be too large because it is computed using today, and;
%* not the date of the most recent return data. This should not cause problems;
data numweeks;
    numweeks=intck('WEEK',&begweek1,today());
run;

proc sql;
    select numweeks into :numweeks from numweeks;    

%* Create a dataset with the beginning and ending of the accumulation period for each week;
data days; run;
%do i=0 %to &numweeks;
    data dayi;
        beg=&begweek1+&i*7;;
	end=&endweek1+&i*7;;
	week=&i; * a unique indicator for each week;
	format beg end mmddyy10.;
    run;

    data days;
	set days dayi;
    run;
%end;

* Generate a list of permnos to generate return data for;
proc sql;
    create table permnos as
	select distinct permno from crsp.msf
	order by permno;

    select count(permno) into :n from permnos; * the number of times to loop;

data permnos;
    set permnos;
    i=_N_; %* a positive integer, counter, corresponding to each permno;
run;

%* create datasets for each group of 100 firms.  Then at the end;
%* merge all datasets together.  Doing this allows the macro to run much quicker;
%* As the dataset gets large, reading and writing takes a lot of time;
%let wsf_list=;
%do j=1 %to %sysevalf(&n/100,ceil);
data wsf&j;
run;
%let wsf_list=&wsf_list wsf&j;
%end;

%put &wsf_list;

%* Given the structure of CRSP data, with indexes formed on Permno, the fastest;
%* way I have found to generate this data is by permno.  However it will take;
%* a day or two to generate.  The following do until loop could be modified;
%* and several processes could be run at once to generate the dataset;
%* for example have one process do from 1 to 5000, etc.;
%* There are around 29,000 permnos as of the date of this macro;
%let i=1;*14335;
%do %until (&i=&n);
proc sql;
    select permno into :permno from permnos where i=&i;

%let i=%EVAL(&i + 1);
%let j=%sysevalf(&i/100,ceil); %* to know which dataset to save it to;

    proc sql;
	create table wsfi as
	    select a.*, b.week
	    from crsp.dsf a left join days b
	    on b.beg le a.date le b.end
	    where permno=&permno
	    order by permno, date;

    proc sql;
        create table wsfi_ret as
	   select permno, week, exp(sum(log(1+ret)))-1 as ret, count(ret) as n_ret
	   from wsfi
	   where not missing(ret)
	   group by permno, week
	   order by permno, week;

    proc sql;	
	create table wsfi_vol as
	    select permno, week, sum(vol*cfacshr) as vol_adj, sum(numtrd) as numtrd
	    from wsfi
	    where not missing(ret)
	    group by permno, week
	    order by permno, week;

    proc sql;
	create table wsfi_oth as
	    select permno, week, date, cfacpr, cfacshr, prc, shrout, bid, ask, bidlo, askhi
	    from wsfi
	    where not missing(ret)
	    group by permno, week
	    having date=max(date)
	    order by permno, week;

data wsfi;
    merge wsfi_ret wsfi_vol wsfi_oth;
    vol=vol_adj/cfacshr; * corrects volume for any stock splits occuring mid-week (together with the above cfacshr adjustment);
    by permno week;
run;

data wsf&j;
    set wsf&j wsfi;
run;

%end;

data wsf;
    set &wsf_list;
run;

proc sql;
    %* the market is closed on some Fridays.  Get the last day of the week the market is open;
    create table mkt_open as
	select week, max(date) as end_of_week
	from wsf
	group by week
	order by week;

proc sql;
    create table wsf as
	select a.*, b.end_of_week
	from wsf a left join mkt_open b
	on a.week=b.week;

data wsf_pwr wsf; %*pwr is partial week return;
    set wsf;
    if date < end_of_week then output wsf_pwr;
    else output wsf;
run;

%* create a missing observation in the week of any partial week return, similar to the daily and monthly;
%* files which fill in missing data with missing observations.  Also, in the last month/week/day of delisting;
%* a dummy observation with missing value is in the database.  This structure allows it to work with the rest;
%* of my macros;
data wsf_miss;
    set wsf_pwr;
    ret=.;
    retx=.;
    prc=.;
    askhi=.;
    ask=.;
    bidlo=.;
    bid=.;
    date=end_of_week;
    drop beg end_of_week;
run;

data wsf;
    set wsf wsf_miss;
run;

proc sort data=wsf out=&outlib..wsf;
    by permno date;
run;

proc sql;
    create index wsf
	on &outlib..wsf(permno, date);

   
%* Create a weekly stock event file (for delistings only);

data dse;
    set crsp.dse;
    where dlstcd > 199;
run;

proc sql;
    create table dse as
	select a.*, b.ret
	from dse a left join wsf_pwr b
	on a.permno=b.permno and b.end_of_week-6 le a.date le b.end_of_week;
    
data &outlib..wse;
    set dse;
    if not missing(ret) and not missing(dlret) then dlret=(1+ret)*(1+dlret)-1;

    if missing(dlret) and not missing(ret) then do;
	dlret=ret;    %* partial week returns in the same way as in the monthly stock file;
	dlpdt=date-1; %* Do not use the dlpdt for anything in this dataset.  This is a flag that ;
	              %* indicates the return is a partial return, excluding the delisting return;
		      %* and that a replacement value needs to be merged;
	end;
run;


%mend;


*options ls=max nocenter mprint;
*data wsf;
*    set st1.wsf;
*run;
*%wsf(begweek1='02jan1926'd,endweek1='08jan1926'd,outlib=st3);
