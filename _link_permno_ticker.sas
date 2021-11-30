/*

Created by Richard Price
Sometime in 2007

* -------------------------------------------------------;
* -------------------------------------------------------;
* Create a file that links tickers over time with permnos;
* -------------------------------------------------------;
* -------------------------------------------------------;

This macro takes the names history of a company, which provides
information on the permno and ticker history of each company
and creates a file that specifies date ranges over which
the permno-ticker link is active.

This is helpful for merging ticker-only data with permno data.
Note, however, that the tickers must be the same (not the funky
tickers from Compustat).
    
The only input parameter is the library name: lib, for you
to save the output dataset.  The output dataset is called
"ticker_small".

An example, AOL, Time Warner

The names history (in crsp.mse file) shows the following
ticker-related records for AOL and TW.

PERMNO   DATE         TICKER

40483    19640429     TL
40483    19680102     TL
40483    19890724     TL
40483    19891211     TWX
40483    19990201     TWX
77418    19920319     AMER
77418    19960916     AOL
77418    20010112     AOL
77418    20010824     AOL
77418    20020102     AOL
77418    20031016     TWX
77418    20040202     TWX

This macro produces the following output:

PERMNO   TICKER           beg           end

40483     TL       04/29/1964    12/10/1989
40483     TWX      12/11/1989    10/15/2003 (note that data actually stops earlier than this)
77418     AMER     03/19/1992    09/15/1996
77418     AOL      09/16/1996    10/15/2003
77418     TWX      10/16/2003    11/13/2006

*/
%macro link_permno_ticker(lib=work);

* First, select all tickers and permnos;

data ticker;
    set crsp.mse;
    where event="NAMES" and not missing(ticker);
* to do a little debugging;
*   where event="NAMES" and not missing(ticker) and permno in (77418 40483);
*   where event="NAMES" and not missing(ticker) and permno in (38877 64151 77297 88278);
    keep permno date ticker;
run;

proc sort data=ticker;
    by ticker date;
run;

data ticker;
    set ticker;
    format begdate mmddyy10.;
    by ticker;
    retain a; * a is the nth permno for the ticker;
    
    tickerm1=lag(ticker);
    permnom1=lag(permno);
    
    if first.ticker then do;
	a=1;
	begdate=date;
	end;
    else if tickerm1=ticker and permnom1=permno then do;
	*nothing;
	end;
    else if tickerm1=ticker and permnom1 ne permno then do;
	a=a+1;
	begdate=date;
	end;
run;

proc sort data=ticker;
    by ticker descending date;
run;

data ticker;
    set ticker;
    format datep1 mmddyy10. enddate mmddyy10.;
    by ticker;
    retain b; *like a, in reverse;
    
    tickerp1=lag(ticker);
    datep1=lag(date);
    permnop1=lag(permno);

    if first.ticker then do;
        b=1;
*       enddate=date;
        enddate=today();
        end;
    else if tickerp1=ticker and permnop1 = permno then do;
        * nothing;
	end;
    else if tickerp1=ticker and permnop1 ne permno then do;
	b=b+1;
*	enddate=date;
	enddate=datep1-1;
	end;
   drop permnom1 permnop1 datep1 tickerm1 tickerp1;
run;

proc sort data=ticker;
    by permno date;
run;

data ticker;
    set ticker;
    format begdate2 mmddyy10.;
    by permno;
    retain a2; * a2 is the nth ticker for the permno;
    
    tickerm1=lag(ticker);
    permnom1=lag(permno);
    
    if first.permno then do;
	a2=1;
	begdate2=date;
	end;
    else if tickerm1=ticker and permnom1=permno then do;
	*nothing;
	end;
    else if tickerm1 ne ticker and permnom1 = permno then do;
	a2=a2+1;
	begdate2=date;
	end;
run;

proc sort data=ticker;
    by permno descending date;
run;

data ticker;
    set ticker;
    format datep1 mmddyy10. enddate2 mmddyy10.;
    by permno;
    retain b2; *like a2, in reverse;
    
    tickerp1=lag(ticker);
    datep1=lag(date);
    permnop1=lag(permno);

    if first.permno then do;
        b2=1;
*       enddate2=date;
        enddate2=today();
        end;
    else if tickerp1=ticker and permnop1 = permno then do;
        * nothing;
	end;
    else if tickerp1 ne ticker and permnop1 = permno then do;
	b2=b2+1;
*	enddate2=date;
	enddate2=datep1-1;
	end;
run;

proc sql;
    create table t1 as
	select permno, ticker, a, b, a2, b2, begdate
	from ticker
	where not missing(begdate)
	order by permno, ticker, a, b, a2, b2;
    
    create table t2 as
	select permno, ticker, a, b, a2, b2, enddate
	from ticker
	where not missing(enddate)
	order by permno, ticker, a, b, a2, b2;
	
    create table t3 as
	select permno, ticker, a, b, a2, b2, begdate2
	from ticker
	where not missing(begdate2)
	order by permno, ticker, a, b, a2, b2;
    
    create table t4 as
	select permno, ticker, a, b, a2, b2, enddate2
	from ticker
	where not missing(enddate2)
	order by permno, ticker, a, b, a2, b2;

data t;
    merge t1 t2 t3 t4;
    by permno ticker a b a2 b2;
run;


data &lib..ticker_small;
    set t;
    format beg mmddyy10. end mmddyy10.;
    beg = max(begdate, begdate2);
    end = min(enddate, enddate2);
    drop begdate: enddate: a b a2 b2;
run;

%mend link_permno_ticker;
