/*
**** Macro exchcd_small_daily
**** Created by Richard Price
**** December 15, 2006

This macro is better than exchcd_small, which uses monthly data.
This macro uses daily data to get precise date ranges for when
data are missing.

This macro is used with the _get_tempdlret macro. The macro creates a
dataset that shows the history of exchange codes for each permno.  The
exchange codes provided by CRSP include:

-2 Halted By NYSE Or AMEX
-1 Suspended By NYSE, AMEX, or NASDAQ
0  Not Trading On NYSE, AMEX, or NASDAQ
1  NYSE
2  AMEX
3  NASDAQ
5  Mutual Funds (As Quoted By NASDAQ)
9  Did not trade, unknown reason (as told to me by CRSP tech support)
10 Boston Stock Exchange
13 Chicago Stock Exchange
16 Pacific Stock Exchange
17 Philadelphia Stock Exchange
19 Toronto Stock Exchange
20 Over-The-Counter (Non-NASDAQ Dealer Quotations)
31 When-Issued Trading On NYSE
32 When-Issued Trading On AMEX
33 When-Issued Trading On NASDAQ

Return data are generally not missing for exchange codes 1 2 3 31 32
33.  For the rest, return data are missing.

Much of the missing return data are explained by exchange codes other
than 1 2 3 31 32 33.  If it was halted, suspended or otherwise
temporarily delisted or simply not trading, the exchange code is one
of 0 -1 -2.  If it moves from NYSE/AMEX/NASDAQ to another exchange (10
13 16 17 19 sometimes 20) it is often indicated in the data with the
appropriate code.

However, a significant number of observations are still missing return
data (that have exchcd of 1 2 3 31 32 33).  Sometimes the data are
missing for only one day, but other times it is missing for long
periods of time.  There is no exchange code to explain the missing
return data.

This macro first, creates an exchange code history for each permno.
Next, the macro modifies this history to include any other unexplained
missing return data.

Take as an example permno 30832.  There are multiple changes in exchcd
as recorded in CRSP, i indicates the ith exchange code:

PERMNO     i      min_date    EXCHCD      max_date
 30832     1    07/02/1962        2     12/18/1969
 30832     2    12/19/1969        0     10/10/1978
 30832     3    10/11/1978        3     07/20/1980
 30832     4    07/21/1980       17     08/26/1980
 30832     5    08/27/1980        2     11/25/1982
 30832     6    11/26/1982       -1     01/04/1983
 30832     7    01/05/1983        2     12/11/2006

An examination of return data reveals that there are other time
periods during which return data are missing for this permno.  I
create records in this dataset indicating the time periods during
which data are missing.  The variable i is now adjusted by adding
0.001 incrementally to i each time return data are missing.  Sometimes
data are missing for only one day.  In this case, the min_date and
max_date are equal to each other.  If return data are missing for more
than one day, the range specifies the dates with missing data.

I assign a value to exchcd of -5 for return data that are missing for
more than one day and -6 when they are missing for only one day when
the exchcd is 1 2 3 31 32 33.

With these new exchange codes along with the min_date and max_date
variables, you can determine whether it is appropriate to use 0 as a
replacement value for the missing return (probably okay for EXCHCD=-6,
may be okay for EXCHCD=-5 if the range is sufficiently short.

The dataset is modified as follows (in part -- it is very long):

PERMNO      i        min_date    EXCHCD      max_date

 30832    1.000    07/02/1962        2     08/05/1962
 30832    1.001    08/06/1962       -6     08/06/1962
 30832    1.002    08/07/1962        2     10/11/1962
 30832    1.003    10/12/1962       -6     10/12/1962
 30832    1.004    10/13/1962        2     03/04/1964
 30832    1.005    03/05/1964       -6     03/05/1964
 30832    1.006    03/06/1964        2     10/10/1978
 30832    2.000    12/19/1969        0     10/10/1978
 30832    3.000    10/11/1978        3     11/05/1979
 30832    3.001    11/06/1979       -5     11/08/1979
 30832    3.002    11/09/1979        3     03/27/1980
 30832    3.003    03/28/1980       -5     04/09/1980
 30832    3.004    04/10/1980        3     04/23/1980
 30832    3.005    04/24/1980       -6     04/24/1980
 30832    3.006    04/25/1980        3     06/24/1980
 30832    3.007    06/25/1980       -6     06/25/1980
 30832    3.008    06/26/1980        3     08/26/1980
 30832    4.000    07/21/1980       17     08/26/1980
 30832    5.000    08/27/1980        2     08/10/1982
 30832    5.001    08/11/1982       -6     08/11/1982
 30832    5.002    08/12/1982        2     08/16/1982
 30832    5.003    08/17/1982       -6     08/17/1982
 30832    5.004    08/18/1982        2     01/04/1983
 ...

* Input Parameters
* ---------------------------------------------------------------------
* dsetout:     Name of the output dataset.  Default value is exchcd_small, which
*              is created in the working directory.  Specify something different.
*              if you want.  If you plan on using it multiple times, it would
*              be a good idea to save the dataset so you do not have to create it
*              multiple times.  The get_tempdlret macro has as an option to specify
*              the path to the dataset
*
* exchcd_list: The list of exchange codes that should have valid return data
*              The default value is 1 2 3 31 32 33.
*
* debug:       If you want to debug, or see how a specific permno is affected
*              set debug=1 and use the test and test2 macro variables below
*              to specify the permnos you want.  Relevant datasets will be
*              printed in the lst file.  The default value is 0.
*
* test:        Used for debugging.  The default value is null.
*              If you want to restrict the permnos in the dataset
*              test=%STR(and permno in (82506 89847 90608 79063 72531 89386 10924 10012))
*
* test2:       Also used for debugging.  Set as follows.  Default is null.
*              test2=%STR(where permno in (82506 89847 90608 79063 72531 89386 10924 10012))
*
* suppress:    If you want to avoid creating a separate entry in the exchcd
*              dataset for every missing return you can use the suppress variable.
*              If you set suppress=n, missing returns are ignored when there are fewer than n+1
*              consecutive days of missing returns.
*              (Then when you merge the exchcd_small dataset with other datasets, you can
*              set returns = 0 for short lived missing returns).  Default is null.

* Note: There is no input dataset.

* Output Dataset
* ---------------------------------------------------------------------
* This macro creates an output dataset containing the following variables:
*
* permno:      Duh.
*
* i;           The ith change in exchange code.
*              When i has a decimal it is of the form i.j where nonmissing
*              j indicates that missing return data exist in the original
*              i range contained in CRSP.  This original range is divided
*              into intervals of missing and nonmissing data.  See the above
*              example for more details.
*
* min_date:    The beginning of the range for that exchcd
*
* max_date:    The ending of the range for that exchcd (the last exchcd is set
*              to the latest possible date -- i.e. today).
*
* exchcd:      The exchange code, as provided by CRSP, or by me (exchcd=-6 or -5)
*              as explained above.
*

To test the macro:

%exchcd_small_daily(dsetout=test,debug=1,
    test=%STR(and permno in (82506 89847 90608 79063 72531 89386 10924 10012)),
    test2=%STR(where permno in (82506 89847 90608 79063 72531 89386 10924 10012)));

%exchcd_small_daily(dsetout=test,debug=1,
    test=%STR(and permno in (88669 79362 80524 85524 87577)),
    test2=%STR(where permno in (88669 79362 80524 85524 87577)));
    
To operate the macro normally and save the output somewhere:

libname home '/home/rice/richardp/';
%exchcd_small_daily(dsetout=home.exchcd_small_daily);
    
*/

%macro exchcd_small_daily(dsetout=exchcd_small_daily,suppress=,exchcd_list = 1 2 3 31 32 33,debug=0,test=,test2=);

%* Note: it does not matter if you use mse or dse for the next proc sql statement;
proc sql;
    create table exchcd as
        select permno, date, exchcd
        from crsp.dse
        where not missing(exchcd)
        order by permno, date;
    
data exchcd;
    set exchcd;
    by permno;
    retain i; * i is a counter that indicates when a change in exchcd occurs;

    exchcdm1=lag(exchcd);
    if first.permno then i=1;
    else if exchcdm1 ne exchcd then i=i+1;
run;

proc sql;
    create table exchcd_small as
        select permno, i, min(date) as min_date format mmddyy10., exchcd
        from exchcd
        group by permno, i, exchcd
        order by permno, i descending;

data exchcd_small;
    set exchcd_small;
    by permno;
    format max_date mmddyy10.;

    max_date=lag(min_date)-1;    

    if first.permno then max_date=today();
    &test2;
run;

proc sort data=exchcd_small;
    by permno min_date;
run;

%if &debug=1 %then %do;
title 'exchcd_small';
    proc print data=_last_;
    run;
title;
%end;

proc sql;
    * all monthly observations with missing returns;
    create table mrt as
        select permno, date, ret
        from crsp.dsf
        where missing(ret) &test;

    * the first non-missing return for the permno;
    create table mindt as
        select permno, min(date) as first_date
        from crsp.dsf
        where not missing(date) &test
        group by permno;
    
    * the last non-missing return for the permno;    
    create table maxdt as
        select permno, max(date) as last_date
        from crsp.dsf
        where not missing(date) &test
        group by permno;

    * merge the first and last dates with the mrt dataset;
    * keep only missing returns that are within those ranges;
    create table mrt as
        select a.permno, a.date, a.ret, b.first_date format date9.
        from mrt a left join mindt b
        on a.permno=b.permno;
    
    create table mrt as
        select a.*, b.last_date format date9.
        from mrt a left join maxdt b
        on a.permno=b.permno
        order by permno, date;

%if &debug=1 %then %do;
title 'All missing returns for dataset mrt';
    proc print data=_last_;
    run;
title;
%end;

proc sql;
    create table mrt2 as
        select * from mrt
        where last_date > date > first_date;

%if &debug=1 %then %do;
title 'All missing returns for dataset mrt within first_date, last_date range';
    proc print data=_last_;
    run;
title;
%end;
    
    %* keep only those returns for which the exchcd does not;
    %* explain the missing return data;
    %* I.E., firms that have the exchcd = 1 2 3 31 32 33;
proc sql;
    create table mrt2 as
        select a.*, b.*
        from mrt2 a left join exchcd_small b
        on a.permno=b.permno and
        intck('DAY',b.min_date, a.date) > 0 and
        intck('DAY',a.date,b.max_date) ge 0 and
        b.exchcd in (&exchcd_list);

    %* NOTE: using the intck > 0 will allow returns at the beginning;
    %* of a return period to be missing because it is the first day;
    %* with a valid price, but lagged price is missing, so returns;
    %* are missing.;
    
    create table mrt2 as
        select * from mrt2
        where not missing(exchcd)
        order by permno, date;
    
%if &debug=1 %then %do;
title 'All missing returns for dataset mrt with exchcd in &exchcd_list';
    proc print data=_last_;
    run;
title;
%end;

%*****try collapsing range first as much as possible;
* adj is a variable that indicates whether the missing return is adjacent to another missing ret;
data mrt2;
    set mrt2;
    datem1=lag(date);
    by permno;
    
    if first.permno then do;
        adj=.;
        datem1=.;
    end;

    else if intck('WEEKDAY',datem1,date)=1 then adj=1;
    else adj=0;
run;

proc sort data=mrt2;
    by permno descending date;
run;

data mrt2;
    set mrt2;
    datep1=lag(date);
    by permno;
    
    if first.permno then do;
        datep1=.;
    end;
    else if intck('WEEKDAY',date,datep1)=1 then adj=1;
run;

proc sort data=mrt2;
    by permno date;
run;

%* To collapse the ranges, (for those returns that are one weekday apart);
%* need to create a variable that I can group by with _MIN is the min_date;
%* for each adjacent range.  After this, a proc sql statement with min and;
%* max date grouped by _MIN will collapse the date ranges significantly;
data mrt2;
    set mrt2;
    format _MIN mmddyy8.;
    by permno;
    retain _MIN oldadj;
    
    if first.permno then do;
        oldadj=adj;
        _MIN=date;
    end;
    else if adj=1 and oldadj=1 then do;
        * nothing, keep the existing value of _MIN for that record;
    end;
    else if adj=1 and oldadj in (. 0) then do;
        oldadj=adj;
        _MIN=date;
    end;
    else if adj=0 then do;
        _MIN=date;
        oldadj=adj;
    end;
run;

%if &debug=1 %then %do;
title 'dataset mrt2 showing min date and whether it is adj';
    proc print data=_last_;
    run;
title;
%end;

proc sql;
    create table mrt3 as
        select permno, min(date) as min_date2 format mmddyy8., max(date) as max_date2 format mmddyy8.,
        _MIN format mmddyy8., adj, min_date, max_date, exchcd
        from mrt2
        group by permno, _MIN, adj, min_date, max_date, exchcd
        order by adj, permno, _MIN;

%if &debug=1 %then %do;
title 'dataset mrt3 showing collapsed date ranges, not adjusting for holidays';
    proc print data=_last_;
    run;
title;
%end;

%* determine whether the missing return is for a single day, or whether it spans several days;
%* I previously tried to do the entire date range collapsing with the following code;
%* (excluding the above 80 lines of code, but it was too computer intensive);
%* The following lines of code take take into account holidays, where intck('WEEKDAY') would;
%* fail to identify adjacent missing returns;
proc sql;
    %* First, merge lagged returns;
    create table miss123 as
        select a.permno, a.min_date2, a.max_date2, a.min_date, a.max_date, a.exchcd, b.ret as retm1, max(b.date) as datem1 format mmddyy10.
        from mrt3 a left join crsp.dsf b
        on a.permno=b.permno
        where b.date < a.min_date2
        group by a.permno, a.min_date2, a.max_date2, a.min_date, a.max_date, a.exchcd
        having max(b.date)=b.date
        order by permno, min_date2;

proc sql;
    %* Next, merge lead returns;
    create table miss123 as
        select a.permno, a.min_date2, a.max_date2, a.min_date, a.max_date, a.exchcd, a.retm1, a.datem1, b.ret as retp1, min(b.date) as datep1 format mmddyy10.
        from miss123 a left join crsp.dsf b
        on a.permno=b.permno
        where b.date > a.max_date2
        group by a.permno, a.min_date2, a.max_date2, a.min_date, a.max_date, a.exchcd, a.retm1, a.datem1
        having min(b.date)=b.date
        order by permno, min_date2;

%* If lead or lag returns are missing along with current returns, it means;
%* that the return is adjacent to another missing return and they should;
%* be combined in a single record.;
data miss123;
    format group_by_date mmddyy10.;
    set miss123;
    by permno;
    retain keepdate;

    if not missing(datem1) and not missing(datep1) then do;
        if not missing(retm1) and missing(retp1) then do;
            adj2=1;
            keepdate=min_date2;
            group_by_date=min_date2;
            end;
        else if missing(retm1) and missing(retp1) then do;
            adj2=1;
            group_by_date=keepdate;
            end;
        else if missing(retm1) and not missing(retp1) then do;
            adj2=1;
            group_by_date=keepdate;
            end;
        else do;
            adj2=0;
            group_by_date=min_date2;
            end;
    end;
run;

%if &debug=1 %then %do;
title 'Missing returns with adjacent/nonadjacent classification';
    proc print data=_last_;
    run;
title;
%end;


%* Combine adjacent returns into a single record;
%*;
%* min_date2 and min_date3 will have the following relationship: ;
%*    min_date3 le min_date2.  They will be equal when the first;
%*    set of code correctly identified the missing return range;
%*    And min_date3 will be less than min_date2 when there was;
%*    a holiday before min_date2;
%*;
%* max_date2 and max_date 3 have a more complicated relationship;
%* If there were no holidays, then the first set of code sets the;
%* max date.  If there were holidays, then max_date3 sets the max_date;
%* If there are no holidays, then max_date3 is unusable, set to the;
%* value of min_date2 most likely;

proc sql;
    create table miss123 as
        select permno, min_date, max_date, exchcd,
        min(min_date2) as min_date3 format mmddyy10.,
        max(max_date2) as max_date3 format mmddyy10.
        from miss123
        group by permno, min_date, max_date, exchcd, group_by_date;

%if &debug=1 %then %do;
title 'Collapsed: Missing returns with adjacent/nonadjacent classification that accounts for holidays';
    proc print data=_last_;
    run;
title;
%end;

%if &suppress ne %then %do;
    data miss123;
        set miss123;
        if (intck('DAY',min_date3,max_date3) < &suppress) then delete;
    run;
%end;

proc sql;
    %* Update the exchcd so that all missing returns are identified by an appropriate exchcd;
    create table exchcd_small_replace as
        select distinct b.*, b.min_date as min_date_orig, b.max_date as max_date_orig, b.exchcd as exchcd_orig
        from miss123 a inner join exchcd_small b
        on a.permno=b.permno and a.max_date=b.max_date and a.min_date=b.min_date;

    create table exchcd_small_newobs as
        select permno, -5 as exchcd, min_date3 as min_date, max_date3 as max_date, min_date as min_date_orig,
        max_date as max_date_orig, exchcd as exchcd_orig
        from miss123;

%if &debug=1 %then %do;
title 'dataset exchcd_small_replace, contains entries to be replaced';
    proc print data=exchcd_small_replace;
run;

title 'dataset exchcd_small_newobs, to be inserted into exchcd_small';
    proc print data=exchcd_small_newobs;
    run;
title;
%end;
    
data firstobs;
    set exchcd_small_replace;
    max_date=.;
run;

data intermediateobs;
    set exchcd_small_newobs;
    max_date=.;
run;

data insert_new_exchcd;
    set firstobs intermediateobs exchcd_small_newobs;
run;

proc sort data=insert_new_exchcd;
    by permno descending min_date max_date;
run;

%if &debug=1 %then %do;
title 'dataset insert_new_exchcd';
    proc print data=_last_;
    run;
title;
%end;

data insert_new_exchcd;
    set insert_new_exchcd;
    by permno;
    min_datep1=lag(min_date);
    
    if first.permno and missing(max_date) then do;
        max_date=max_date_orig;
        exchcd=exchcd_orig;
        end;
    else if missing(max_date) then do;
        max_date=min(intnx('DAY',min_datep1,-1),max_date_orig);
        exchcd=exchcd_orig;
        end;
run;

proc sort data=insert_new_exchcd;
    by permno min_date max_date;
run;

data insert_new_exchcd;
    set insert_new_exchcd;
    by permno;
    max_datem1=lag(max_date);
    
    if first.permno then do;
        %* nothing to do;
        end;
    else if exchcd=exchcd_orig then do;
        min_date=intnx('DAY',max_datem1,1);
        end;
run;

%if &debug=1 %then %do;
title 'insert_new_exchcd with fixed min and max dates';
    proc print data=_last_;
    run;
title;
%end;

proc sort data=insert_new_exchcd;
    by permno min_date_orig min_date;
run;

data insert_new_exchcd;
    set insert_new_exchcd;
    by permno min_date_orig;
    retain i_old;
    
    if first.min_date_orig then do;
        i_old=i;
        end;
    else if missing(i) then do;
        i=i_old+0.001;
        i_old=i_old+0.001;
        end;
run;

%if &debug=1 %then %do;
title 'dataset insert_new_exchcd';
    proc print data=_last_;
    run;
title;
%end;

**** NEED TO REMOVE OLD ENTRY, REPLACE IT WITH insert_new_exchcd;

* finally, remove the original entry from exchcd_small and replace it with;
* the new range;

proc sql;
    create table exchcd_small_new as
        select a.*, b.min_date as if_not_null_delete
        from exchcd_small a left join firstobs b
        on a.permno=b.permno and a.min_date=b.min_date;
    
data exchcd_small_new;
    set exchcd_small_new;
    if missing(if_not_null_delete);
run;

%if &debug=1 %then %do;
title 'exchcd_small_new';
    proc print data=_last_;
    run;
title;
%end;

data &dsetout;
    set insert_new_exchcd exchcd_small_new;
    if exchcd=-5 and min_date=max_date then exchcd=-6;
    iint=floor(i);
    drop min_date_orig max_date_orig i_old min_datep1 max_datem1 exchcd_orig remove if_not:;
run;   

proc sort data=&dsetout;
    by permno i;
run;

data &dsetout;
    set &dsetout;
    retain exchcd_crsp;
    by permno iint;
    if first.iint then exchcd_crsp=exchcd;
    drop iint;
run;

%if &debug=1 %then %do;
title "&dsetout";
    proc print data=_last_;
    run;
title;
%end;

%mend exchcd_small_daily;
