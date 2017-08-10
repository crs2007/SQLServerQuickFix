# MS SQL Server Quick Fix
This is a T-SQL script by Rimer Sharon.
Fix default behaviour of SQL Server

### Support
- [x] SQL Server 2005 and Up
- [x] Case sensitive
- [x] SQL Server 2017(With Linux) support

### Installation
If you are using SSMS 2016 and above you should turn on the option - ["Retain CR/LF (carriage return / Line Feed) on copy or save"](https://blog.sqlauthority.com/2016/06/03/sql-server-maintain-carriage-return-enter-key-ssms-2016-copy-paste/)
Just run script as-is on your SQL Server.
Deside what of the output you want to run, in order to fix issue.
### Security Configuration
Make sure you have system administrator privilege on the SQL server instance.
### Useful links
1. [SQL best practices for Biztalk](https://blogs.msdn.microsoft.com/blogdoezequiel/2009/01/25/sql-best-practices-for-biztalk)
2. [Best practices for SQL Server in a SharePoint Server farm](https://technet.microsoft.com/en-us/library/hh292622.aspx)  

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


### Disclaimer
This code and information are provided "AS IS" without warranty of any kind, either expressed or implied, including but not limited to the implied warranties or merchantability and/or fitness for a particular purpose.  

### Warranty
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### License
This script is free to download and use for personal, educational, and internal corporate purposes, provided that this header is preserved. 
Redistribution or sale of this script, in whole or in part, is prohibited without the author's express written consent.
