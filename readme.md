# MS SQL Server Quick Fix
This is a T-SQL script by Rimer Sharon.
Fix default behaviour of SQL Server

### Support
- [x] SQL Server 2005 and Up
- [x] Case sensitive

### Installation
Just run script as-is on your SQL Server.
Deside what of the output you want to run, in order to fix issue.
### Security Configuration
Make sure you have system administrator privilege on the SQL server instance.
### Useful links
1. [SQL best practices for Biztalk](https://blogs.msdn.microsoft.com/blogdoezequiel/2009/01/25/sql-best-practices-for-biztalk)
2. [Best practices for SQL Server in a SharePoint Server farm](https://technet.microsoft.com/en-us/library/hh292622.aspx)  


### Disclaimer
This code and information are provided "AS IS" without warranty of any kind, either expressed or implied, including but not limited to the implied warranties or merchantability and/or fitness for a particular purpose.  

### License
This script is free to download and use for personal, educational, and internal corporate purposes, provided that this header is preserved. 
Redistribution or sale of this script, in whole or in part, is prohibited without the author's express written consent.

## What this solution will found as an issue?
* PAGE VERIFY
* File Growth
* CURSOR_DEFAULT
* Configuration:
    * optimize for ad hoc workloads
    * cost threshold for parallelism
    * remote admin connections
    * backup compression default
* Jobs owner
* Windows Power Plan
* TraceFlag
* Tempdb
* CycleErrorLog
