/*

Created by Richard Price
July 15 2008

* -------------------------------------------------------;
* -------------------------------------------------------;
* Create a file that links cusips over time with permnos;
* -------------------------------------------------------;
* -------------------------------------------------------;

* this is a modification of link_permno_ticker;

This macro takes the names history of a company, which provides
information on the permno and ticker history of each company
and creates a file that specifies date ranges over which
the permno-ticker link is active.

This is helpful for merging ticker-only data with permno data.
Note, however, that the tickers must be the same (not the funky
tickers from Compustat).
    
The only input parameter is the library name: lib, for you
to save the output dataset.  The output dataset is called
"cusip_small".

An example, AOL, Time Warner

The names history (in crsp.mse file) shows the following
ticker-related records for AOL and TW.

         Exchange
         Ticker    Names         Date of
 PERMNO  Symbol    CUSIP     Observation
----------------------------------------
  40483  TL                     19640429
  40483  TL        88722410     19680102
  40483  TL        88731510     19890724
  40483  TWX       88731510     19891211
  40483  TWX       88731510     19990201
  77418  AMER      02364J10     19920319
  77418  AOL       02364J10     19960916
  77418  AOL       00184A10     20010112
  77418  AOL       00184A10     20010824
  77418  AOL       00184A10     20020102
  77418  TWX       88731710     20031016
  77418  TWX       88731710     20040202
  77418  TWX       88731710     20060526

This macro produces the following output:

   PERMNO    NCUSIP             beg           end

    40483    88722410    01/02/1968    07/23/1989
    40483    88731510    07/24/1989    07/15/2008 (TODAY, although data actually stops earlier)
    77418    00184A10    01/12/2001    10/15/2003
    77418    02364J10    03/19/1992    01/11/2001
    77418    88731710    10/16/2003    07/15/2008

*/
%macro link_permno_cusip(lib=work);

* First, select all ncusips and permnos;

data ncusip;
    set crsp.mse;
    where event="NAMES" and not missing(ncusip);
* to do a little debugging;
*   where event="NAMES" and not missing(ncusip) and permno in (77418 40483);
*   where event="NAMES" and not missing(ncusip) and permno in (38877 64151 77297 88278);
    keep permno date ncusip;
run;

proc sort data=ncusip;
    by ncusip date;
run;

data ncusip;
    set ncusip;
    format begdate mmddyy10.;
    by ncusip;
    retain a; * a is the nth permno for the ncusip;
    
    ncusipm1=lag(ncusip);
    permnom1=lag(permno);
    
    if first.ncusip then do;
	a=1;
	begdate=date;
	end;
    else if ncusipm1=ncusip and permnom1=permno then do;
	*nothing;
	end;
    else if ncusipm1=ncusip and permnom1 ne permno then do;
	a=a+1;
	begdate=date;
	end;
run;

proc sort data=ncusip;
    by ncusip descending date;
run;

data ncusip;
    set ncusip;
    format datep1 mmddyy10. enddate mmddyy10.;
    by ncusip;
    retain b; *like a, in reverse;
    
    ncusipp1=lag(ncusip);
    datep1=lag(date);
    permnop1=lag(permno);

    if first.ncusip then do;
        b=1;
*       enddate=date;
        enddate=today();
        end;
    else if ncusipp1=ncusip and permnop1 = permno then do;
        * nothing;
	end;
    else if ncusipp1=ncusip and permnop1 ne permno then do;
	b=b+1;
*	enddate=date;
	enddate=datep1-1;
	end;
   drop permnom1 permnop1 datep1 ncusipm1 ncusipp1;
run;

proc sort data=ncusip;
    by permno date;
run;

data ncusip;
    set ncusip;
    format begdate2 mmddyy10.;
    by permno;
    retain a2; * a2 is the nth ncusip for the permno;
    
    ncusipm1=lag(ncusip);
    permnom1=lag(permno);
    
    if first.permno then do;
	a2=1;
	begdate2=date;
	end;
    else if ncusipm1=ncusip and permnom1=permno then do;
	*nothing;
	end;
    else if ncusipm1 ne ncusip and permnom1 = permno then do;
	a2=a2+1;
	begdate2=date;
	end;
run;

proc sort data=ncusip;
    by permno descending date;
run;

data ncusip;
    set ncusip;
    format datep1 mmddyy10. enddate2 mmddyy10.;
    by permno;
    retain b2; *like a2, in reverse;
    
    ncusipp1=lag(ncusip);
    datep1=lag(date);
    permnop1=lag(permno);

    if first.permno then do;
        b2=1;
*       enddate2=date;
        enddate2=today();
        end;
    else if ncusipp1=ncusip and permnop1 = permno then do;
        * nothing;
	end;
    else if ncusipp1 ne ncusip and permnop1 = permno then do;
	b2=b2+1;
*	enddate2=date;
	enddate2=datep1-1;
	end;
run;

proc sql;
    create table t1 as
	select permno, ncusip, a, b, a2, b2, begdate
	from ncusip
	where not missing(begdate)
	order by permno, ncusip, a, b, a2, b2;
    
    create table t2 as
	select permno, ncusip, a, b, a2, b2, enddate
	from ncusip
	where not missing(enddate)
	order by permno, ncusip, a, b, a2, b2;
	
    create table t3 as
	select permno, ncusip, a, b, a2, b2, begdate2
	from ncusip
	where not missing(begdate2)
	order by permno, ncusip, a, b, a2, b2;
    
    create table t4 as
	select permno, ncusip, a, b, a2, b2, enddate2
	from ncusip
	where not missing(enddate2)
	order by permno, ncusip, a, b, a2, b2;

data t;
    merge t1 t2 t3 t4;
    by permno ncusip a b a2 b2;
run;


data &lib..cusip_small;
    set t;
    format beg mmddyy10. end mmddyy10.;
    beg = max(begdate, begdate2);
    end = min(enddate, enddate2);
    drop begdate: enddate: a b a2 b2;
run;

%mend link_permno_cusip;

