;; Filename:      oracle.el
;; Description:   Major Mode for editing sql and pl/sql, and interacting with sqlplus.
;; Author:        Stewart W. Bryson of Red Pill Analytics, LLC.
;; Maintainer:    Stewart W. Bryson
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Requires custom, easy-menu
;;;

;; This code is two-parts borrowed, one-part original. It sprang from the desire
;; to combine the functionality of the sqlplus-mode from Jim Lange's original
;; sql-mode with the casing and indenting functionality from Josie Stauffer's 
;; sqled-mode. So I pulled a lot of the code together into oracle-mode (I was 
;; surprised the name wasn't already spoken for) and added some of other functionality I
;; thought was missing. Also included is some invaluable code contributed to
;; the original sql-mode by Thomas Miller of KnowledgeStorm Inc. It provides the
;; ability to interact with multiple SQL*Plus buffers.

;; sql-mode.el, Copyright (C) 1990 Free Software Foundation, Inc., and Jim Lange.
;; sqled-mode.el, Copyright (C) 2003  Josie Stauffer
          
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2 of
;; the License, or (at your option) any later version.
          
;; This program is distributed in the hope that it will be
;; useful, but WITHOUT ANY WARRANTY; without even the implied
;; warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
;; PURPOSE.  See the GNU General Public License for more details.
          
;; You should have received a copy of the GNU General Public
;; License along with this program; if not, write to the Free
;; Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
;; MA 02111-1307 USA


;;; FILE SECTIONS
;;; ============
;;;
;;;      ** 1. USER OPTIONS
;;;      ** 2. ORACLE-MODE
;;;      ** 3. AUTO CASING AND INDENTATION FUNCTIONS
;;;      ** 4. INTERACTIVE COMMENT FUNCTIONS
;;;      ** 5. BULK CASING AND INDENTATION FUNCTIONS
;;;      ** 6. FUNCTIONS FOR USE ON DESC-TABLE OUTPUT
;;;      ** 7. MISCELLANEOUS INTERACTIVE FUNCTIONS
;;;      ** 8. NON-INTERACTIVE UTILITY FUNCTIONS
;;;      ** 9. CONTEXT INFORMATION
;;;;    ** 10. ORACLE-MODE INTERACTING WITH SQLPLUS-MODE
;;;     ** 11. SQLPLUS-MODE AND ACCOMPANYING FUNCTIONS


;;; USAGE
;;; =====
;;;
;;; If the following lines are contained in your .emacs file:
;;;
;;;(setq auto-mode-alist
;;;      (append '(("\\.sql\\'" . oracle-mode)) auto-mode-alist))
;;;
;;; then Emacs should enter oracle-mode when you load a file whose name
;;; ends in ".sql"
;;;
;;; When you have entered oracle-mode, you may get more info by pressing
;;; C-h m. You may also get online help describing various functions by:
;;; C-h d <Name of function you want described>


;;;;                ----------------------
;;;;                 ** 1. USER OPTIONS **
;;;;                ----------------------


(require 'custom)

(defgroup oracle nil
  "Major mode for editing SQL and PL/SQL code and interacting with SQL*Plus."
  :group 'languages)

;;;=============================================================
;;; A. ORACLE-MODE options
;;;=============================================================

(defcustom oracle-file-directory "~/.oraclemode"
  "Directory where oracle temp files and history files are written to."
  :group 'oracle
  :type 'string)

(defcustom oracle-explain-buffer "*Explain*"
  "The name of the explain plan buffer created with `oracle-explain', `oracle-autotrace' and `oracle-autotrace-explain'."
  :group 'oracle
  :type 'string)

(defcustom oracle-append-buffer "*Query*"
  "The name of the generic query buffer. This is called with `oracle-append-query'."
  :group 'oracle
  :type 'string)

(defcustom oracle-edit-buffer "*Edit*"
  "The name of the generic buffer created when EDIT is typed in SQL*Plus."
  :group 'oracle
  :type 'string)

(defcustom oracle-temp-buffer "*Oratemp*"
  "The name of the generic buffer used for several functions."
  :group 'oracle
  :type 'string)


(defcustom oracle-mode-hook nil
  "*List of functions to call when Oracle Mode is invoked.
This is a good place to add Oracle environment specific bindings."
  :type 'hook
  :group 'oracle)

(defcustom oracle-comment-prefix "-- "
  "*Prefix used by some `comment-fill` commands.
`comment-region' and `fill-comment-paragraph' insert this
string at the start of each line.
It is NOT the expression for recognizing the start of a comment
\( see `oracle-comment-start-re' )."
  :type 'string
  :group 'oracle)

(defcustom oracle-leftcomment-start-re "\\-\\-\\-\\|/\\*"
  "*Regular expression for the start of a left-aligned comment.
`comment-region' and `fill-comment-paragraph' insert this
string at the start of each line.
It is NOT the expression for recognizing the start of a comment
\( see `oracle-comment-start-re' )."
  :type 'string
  :group 'oracle)

(defcustom oracle-fill-comment-prefix "/* "
  "*Prefix used by some `comment-fill` commands.
`oracle-fill-comment-paragraph-prefix' and
`oracle-fill-comment-paragraph-postfix' insert this
string at the start of each line.
It is NOT the expression for recognizing the start of a comment
\( see `oracle-comment-start-re' )."
  :type 'string
  :group 'oracle)

(defcustom oracle-fill-comment-postfix " */"
  "*Postfix used by `oracle-fill-comment-paragraph-postfix'.
This string is inserted at the end of each line by
`oracle-fill-comment-paragraph-postfix'."
  :type 'string
  :group 'oracle)

(defcustom oracle-fill-comment-postfix-re "[ \t]*\\*/"
  "*Postfix recognized by some `fill-comment` commands.
A string matching this expression is deleted from the end
of each line when filling a comment paragraph using
`oracle-fill-comment-paragraph-prefix`."
  :type 'string
  :group 'oracle)

(defcustom oracle-comment-start-re
  "\\(^\\(rem \\|remark \\)\\|--+ *\\w+\\|/\\*\\)"
  "*Regular expression for the start of a comment.
\(ie text to be ignored for casing/indentation purposes).
The comment is considered to end at the end of the line."
  :type 'string
  :group 'oracle)

(defcustom oracle-group-fcn-re
  "\\<\\(round\\|sum\\|max\\|min\\|count\\)\\>"
  "*Regular expression for grouping functions.
Used to generate the `GROUP BY' clause in a select statement."
  :type 'string
  :group 'oracle)

(defcustom oracle-plsql-unit-re 
  "^ *\\(overriding +\\)?\\(\\(\\(member\\|constructor\\) +\\)?\\(procedure\\|function\\)\\)"
  "*Regular expression for for constructing a statement navigator."
  :type 'string
  :group 'oracle)

(defcustom oracle-plsql-nav-ratio 3
  "What ratio of the current frame should be used for the statement navigator"
  :group 'oracle
  :type 'number)

(defcustom oracle-plsql-nav-nlines 0
  "Value for nlines to pass to `occur'"
  :group 'oracle
  :type 'number)


;;;=============================================================
;;; B. SQLPLUS-MODE options
;;;=============================================================

(defcustom sqlplus-keep-history nil
  "If non-nil, save current session in file denoted by sqlplus-history-file when exiting."
  :group 'oracle
  :type 'boolean)

(defcustom sqlplus-load-history nil
  "If non-nil, load the contents of sqlplus-history-file when starting."
  :group 'oracle
  :type 'boolean)

(defcustom sqlplus-do-commands-clear nil
  "If non-nil, remove SQL*Plus commands and comments from buffer after starting.
This is only useful when sqlplus-keep-history is non-nil."
  :group 'oracle
  :type 'boolean)

(defcustom sqlplus-do-prompts-clear nil
  "If non-nil, remove multiple SQL*Plus prompts after starting."
  :group 'oracle
  :type 'boolean)

(defcustom sqlplus-do-clear-dangerous-sql nil
  "If non-nil, remove dangerous sql commands from the history file after loading.
This ensures that dangerous commands aren't accidentally executed.
The values in sqlplus-dangerous-sql-re determines the commands to look for."
  :group 'oracle
  :type 'boolean)

(defcustom sqlplus-history-file ".sqlhist"
  "If non-nil, save current session to the history when exiting."
  :group 'oracle
  :type 'string)

(defcustom sqlplus-dangerous-sql-re "drop\\|delete\\|truncate\\|\\(identified by\\)"
  "*Protect the line from auto-indentation.
If `oracle-auto-case-flag'  and/or `oracle-auto-indent-flag'
is non-nil, and a string matching this re is found in the line,
the line is not indented."
  :type 'string
  :group 'oracle)

(defcustom sqlplus-lines-to-keep 1000
  "Number of lines to keep in a SQL*Plus buffer when \\[sqlplus-drop-old-lines] is executed."
  :group 'oracle
  :type 'number)

(defcustom sqlplus-prompt "SQL>"
  "The prompt in SQL*Plus. Should be customized to match prompt customizations in SQL*Plus."
  :group 'oracle
  :type 'string)

(defcustom sqlplus-dict-prefix "ALL"
  "Prefix used to determine the set of views used for pulling objects from the
dictionary, i.e dba_tables, user_tables or all_tables."
  :group 'oracle
  :type 'string)

(defvar sqlplus-prompt-re (concat "^\\([0-9][0-9]:[0-9][0-9]:[0-9][0-9] \\)?\\(" sqlplus-prompt " \\)+")
  "This allows for multi-line SQL statements in SQL*Plus.")

(defvar sqlplus-mode-syntax-table nil
  "Syntax-table used for sqlplus-mode.")

(defcustom sqlplus-startup-commands
  "set pause off
set tab off
set trimout on
set linesize 1000
set pause off
set pagesize 0
set colsep \" | \""
  "*A string of commands that will be sent to SQL*Plus immediately after
it starts up.

Can be used as a replacement for the usual Oracle functionality of login.sql."
  :group 'oracle
  :type 'string)

(defcustom sqlplus-use-startup-commands nil
  "If non-nil, execute sqlplus-startup-commands in each new SQL*Plus buffer when it starts."
  :group 'oracle
  :type 'boolean)


(defcustom sqlplus-sessions-query
  "SET echo off
COLUMN status format a10
SET feedback off
SET serveroutput on

COLUMN username format a15 word_wrapped
COLUMN module format a30 word_wrapped
COLUMN action format a32 word_wrapped
COLUMN client_info format a64 word_wrapped

SELECT username, '('||sid||','||serial#||')' \"SID/Serial\", inst_id ,process, status, module, action, client_info
  FROM gv$session
 WHERE username IS NOT NULL
   AND audsid <> SYS_CONTEXT ('USERENV', 'SESSIONID')
 ORDER BY status DESC, username, module, action;

COLUMN USERNAME format a20
COLUMN sql_text format a55 word_wrapped

SET serveroutput on size 1000000
DECLARE
   x NUMBER;
BEGIN
   FOR x IN
      ( SELECT username||' ('||sid||','||serial#||
               ') ospid = ' ||  process ||
               ' program = ' || program username,
               to_char(logon_time,' Day HH24:MI') logon_time,
               to_char(SYSDATE,' Day HH24:MI') current_time,
               sql_address, last_call_et
          FROM gv$session
	 WHERE status = 'ACTIVE'
           AND audsid <> SYS_CONTEXT ('USERENV', 'SESSIONID')
           AND rawtohex(sql_address) <> '00'
           AND username IS NOT NULL ORDER BY last_call_et )
   LOOP
      FOR y IN ( SELECT MAX(decode(piece,0,sql_text,NULL)) ||
                        MAX(decode(piece,1,sql_text,NULL)) ||
                        MAX(decode(piece,2,sql_text,NULL)) ||
                        MAX(decode(piece,3,sql_text,NULL))
                        sql_text
                   FROM gv$sqltext_with_newlines
                  WHERE address = x.sql_address
                    AND piece < 4)
      LOOP
         IF ( y.sql_text NOT LIKE '%listener.get_cmd%' AND
              y.sql_text NOT LIKE '%RAWTOHEX(SQL_ADDRESS)%')
         THEN
            dbms_output.put_line( '--------------------' );
            dbms_output.put_line( x.username );
            dbms_output.put_line( x.logon_time || ' ' ||
                                  x.current_time||
                                  ' last et = ' ||
                                  x.last_call_et);
            dbms_output.put_line(
				  REPLACE(substr( y.sql_text, 1, 250 ),'\"',NULL) );
         END IF;
      END LOOP;
   END LOOP;
END;
/

SET feedback on"
  "*SQL used for the `sqlplus-sessions' function."
  :group 'oracle
  :type 'string)

(defcustom sqlplus-current-sql-query
   "select sql_text
      from gv$sqlarea sqlarea, gv$session sesion
     where sesion.sql_hash_value = sqlarea.hash_value
       and sesion.sql_address    = sqlarea.address
       and sesion.username is not null
       and sid = &sid
       and serial# = &serial;"

  "*SQL used from `sqlplus-current-sql' function."
  :group 'oracle
  :type 'string)


(defcustom sqlplus-longops-query 
  "SELECT replace(opname,'''s',null) operation,
          target,
          (sofar/totalwork)*100 \"Percent Complete\"
     FROM gv$session_longops 
    where sid = &sid
      and serial# = &serial
 order by time_remaining;"

  "The query used to find long operations."
  :group 'oracle
  :type 'string)

(defcustom sqlplus-longops-px-query 
  "SELECT sid,
          REPLACE(sl.opname,'''s',NULL)
          operation,
          sl.target,
          (sl.sofar/sl.totalwork)*100 \"Percent Complete\"
     FROM gv$px_session px1
     JOIN gv$session_longops sl
          USING (sid,serial#)
    WHERE px1.qcsid IN (SELECT DISTINCT px2.qcsid
		       FROM gv$px_session px2
		      WHERE sid = &sid)
    ORDER BY time_remaining;"

  "The query used to find long operations fro a parallel query group."
  :group 'oracle
  :type 'string)

(defcustom sqlplus-waits-query 
  "SELECT event,
          wait_class,
          time_waited, 
          total_waits, 
          average_wait 
     FROM gv$session_event 
    WHERE sid=&sid 
    ORDER BY time_waited ASC;

   SELECT event,
          wait_class,
          seconds_in_wait, 
          wait_time, 
          state 
     FROM gv$session_wait 
    WHERE sid=&sid 
    ORDER BY seconds_in_wait DESC;"

  "The query used to generate the current and combined waits for a particular session."
  :group 'oracle
  :type 'string)

(defcustom sqlplus-waits-px-query 
  "SELECT event,
       wait_class,
       SUM(time_waited) time_waited,
       SUM(total_waits) total_waits,
       AVG(average_wait) average_wait
  FROM gv$px_session px1
  JOIN gv$session_event sl
       USING (sid)
 WHERE px1.qcsid IN (SELECT DISTINCT px2.qcsid
		       FROM gv$px_session px2
		      WHERE sid = &sid)
 GROUP BY event,wait_class
 ORDER BY time_waited;

SELECT event,
       wait_class,
       SUM(seconds_in_wait) seconds_in_wait,
       SUM(wait_time) wait_time
  FROM gv$px_session px1
  JOIN gv$session_wait sl
       USING (sid)
 WHERE px1.qcsid IN (SELECT DISTINCT px2.qcsid
		       FROM gv$px_session px2
		      WHERE sid = &sid)
 GROUP BY event,wait_class
 ORDER BY seconds_in_wait;"

  "The query used to generate the current and combined waits for a particular group a parallelized sessions."
  :group 'oracle
  :type 'string)


(defcustom sqlplus-object-ddl-query
   (concat 
    "SELECT dbms_metadata.get_ddl(decode(object_type,'MATERIALIZED VIEW','MATERIALIZED_VIEW','DATABASE LINK','DB_LINK',object_type), object_name, owner) AS \" \"
  FROM " sqlplus-dict-prefix "_objects
 WHERE object_name like upper('%&object%') 
   AND object_type NOT LIKE upper('%body') 
   AND object_type NOT LIKE upper('%partition') 
 ORDER BY object_type;")

  "*SQL used in `sqlplus-object-ddl' function."
  :group 'oracle
  :type 'string)

(defcustom sqlplus-tablespace-ddl-query
   (concat 
    "select dbms_metadata.get_ddl('TABLESPACE', tablespace_name) as TABLESPACE_DDL
       FROM dba_tablespaces
      WHERE tablespace_name=upper('&object');")

  "*SQL used in `sqlplus-tablespace-ddl' function."
  :group 'oracle
  :type 'string)

(defcustom sqlplus-user-ddl-query
   (concat 
    "select dbms_metadata.get_ddl('USER', username) as USER_DDL
       FROM " sqlplus-dict-prefix "_users
      WHERE username=upper('&object');")

  "*SQL used in `sqlplus-user-ddl' function."
  :group 'oracle
  :type 'string)

(defcustom sqlplus-index-ddl-query
   (concat 
    "select dbms_metadata.get_ddl('INDEX', index_name, owner) as INDEX_DDL
       FROM " sqlplus-dict-prefix "_indexes
      WHERE table_name=upper('&object');")

  "*SQL used in `sqlplus-index-ddl' function."
  :group 'oracle
  :type 'string)

(defcustom sqlplus-desc-tab-query
   "SET define on
SET echo off
SET recsep off
COLUMN dummy noprint
COLUMN type format A15
COLUMN name format A30
COLUMN infos format A45 word_wrapped
COLUMN n format a5
BREAK on col# on name on N on type
SET verify off
SET feedback off
SET timing off

SELECT '&object' as \" \" from dual;

SELECT c.col# dummy,
       c.name,
       decode(c.null$, 0, '', '*') n,
       decode(c.type#, 1, decode(c.charsetform, 2, 'NVARCHAR2(', 'VARCHAR2(')
               || to_char(c.length) || ')',
               2, decode(c.precision#,
                          126, 'FLOAT',
                          'NUMBER' || decode(c.scale, NULL, '',
                                              '(' || to_char(nvl(c.precision#,
								  (c.length - 3) * 2))
                                              || decode(c.scale, 0, ')',
							 ',' || to_char(c.scale)
                                                         || ')'))),
               8, 'LONG',
               9, decode(c.charsetform, 2, 'NCHAR(', 'VARCHAR(')
               || to_char(c.length) || ') VARYING',
               12, 'DATE',
               23, 'RAW' || '(' || to_char(c.length) || ')',
               24, 'LONG RAW',
               69, 'ROWID',
               96, decode(c.charsetform, 2, 'NCHAR(', 'CHAR(')
               || to_char(c.length) || ')',
               105, 'MLSLABEL',
               106, 'MLSLABEL',
               111, ot.name || '(REF)',
               112, decode(c.charsetform, 2, 'NCLOB', 'CLOB'),
               113, 'BLOB',
               114, 'BFILE',
               115, 'CFILE',
               121, ot.name,
               122, ot.name,
               123, ot.name,
               to_char(c.type#)) TYPE,
       substr(cm.comment$, 1, 1000) infos,
       0 dummy
  FROM sys.obj$ o,
       sys.user$ u,
       sys.col$ c,
       sys.coltype$ ct,
       sys.obj$ ot,
       sys.com$ cm
 WHERE u.name = decode(instr('&object', '.'), 0, USER,
			upper(substr('&object', 1, instr('&object', '.') - 1)))
   AND o.name = upper(substr('&object', instr('&object', '.') + 1))
   AND u.user# = o.owner#
   AND o.obj# = c.obj#
   AND c.obj# = ct.obj# (+)
   AND c.col# = ct.col# (+)
   AND ct.toid = ot.oid$ (+)
   AND cm.obj# = o.obj#
   AND cm.col# = c.col#
   AND c.col# > 0
       UNION
SELECT c.col#,
       c.name,
       decode(c.null$, 0, '', '*') n,
       decode(c.type#, 1, decode(c.charsetform, 2, 'NVARCHAR2(', 'VARCHAR2(')
               || to_char(c.length) || ')',
               2, decode(c.precision#,
                          126, 'FLOAT',
                          'NUMBER' || decode(c.scale, NULL, '',
                                              '(' || to_char(nvl(c.precision#,
								  (c.length - 3) * 2))
                                              || decode(c.scale, 0, ')',
							 ',' || to_char(c.scale)
                                                         || ')'))),
               8, 'LONG',
               9, decode(c.charsetform, 2, 'NCHAR(', 'VARCHAR(')
               || to_char(c.length) || ') VARYING',
               12, 'DATE',
               23, 'RAW' || '(' || to_char(c.length) || ')',
               24, 'LONG RAW',
               69, 'ROWID',
               96, decode(c.charsetform, 2, 'NCHAR(', 'CHAR(')
               || to_char(c.length) || ')',
               105, 'MLSLABEL',
               106, 'MLSLABEL',
               111, ot.name || '(REF)',
               112, decode(c.charsetform, 2, 'NCLOB', 'CLOB'),
               113, 'BLOB',
               114, 'BFILE',
               115, 'CFILE',
               121, ot.name,
               122, ot.name,
               123, ot.name,
               to_char(c.type#)) TYPE,
       '*** PK ' || to_char(cc.pos#) || '/' || to_char(cd.cols),
       1
  FROM sys.obj$ o,
       sys.user$ u,
       sys.col$ c,
       sys.coltype$ ct,
       sys.obj$ ot,
       sys.cdef$ cd,
       sys.ccol$ cc
 WHERE u.name = decode(instr('&object', '.'), 0, USER,
			upper(substr('&object', 1, instr('&object', '.') - 1)))
   AND o.name = upper(substr('&object', instr('&object', '.') + 1))
   AND u.user# = o.owner#
   AND o.obj# = c.obj#
   AND c.col# > 0
   AND c.obj# = ct.obj# (+)
   AND c.col# = ct.col# (+)
   AND ct.toid = ot.oid$ (+)
   AND cd.obj# = o.obj#
   AND cd.type# = 2
   AND cd.con# = cc.con#
   AND cc.obj# = o.obj#
   AND cc.col# = c.col#
       UNION
SELECT c.col#,
       c.name,
       decode(c.null$, 0, '', '*') n,
       decode(c.type#, 1, decode(c.charsetform, 2, 'NVARCHAR2(', 'VARCHAR2(')
               || to_char(c.length) || ')',
               2, decode(c.precision#,
                          126, 'FLOAT',
                          'NUMBER' || decode(c.scale, NULL, '',
                                              '(' || to_char(nvl(c.precision#,
								  (c.length - 3) * 2))
                                              || decode(c.scale, 0, ')',
							 ',' || to_char(c.scale)
                                                         || ')'))),
               8, 'LONG',
               9, decode(c.charsetform, 2, 'NCHAR(', 'VARCHAR(')
               || to_char(c.length) || ') VARYING',
               12, 'DATE',
               23, 'RAW' || '(' || to_char(c.length) || ')',
               24, 'LONG RAW',
               69, 'ROWID',
               96, decode(c.charsetform, 2, 'NCHAR(', 'CHAR(')
               || to_char(c.length) || ')',
               105, 'MLSLABEL',
               106, 'MLSLABEL',
               111, ot.name || '(REF)',
               112, decode(c.charsetform, 2, 'NCLOB', 'CLOB'),
               113, 'BLOB',
               114, 'BFILE',
               115, 'CFILE',
               121, ot.name,
               122, ot.name,
               123, ot.name,
               to_char(c.type#)) TYPE,
       '*** IDX ' || oi.name || decode(bitand(i.property, 1), 0, ' ', '(U) ')
       || to_char(ic.pos#) || '/' || to_char(i.cols),
       3
  FROM sys.obj$ o,
       sys.user$ u,
       sys.col$ c,
       sys.coltype$ ct,
       sys.obj$ ot,
       sys.ind$ i,
       sys.obj$ oi,
       sys.icol$ ic
 WHERE u.name = decode(instr('&object', '.'), 0, USER,
			upper(substr('&object', 1, instr('&object', '.') - 1)))
   AND o.name = upper(substr('&object', instr('&object', '.') + 1))
   AND u.user# = o.owner#
   AND o.obj# = c.obj#
   AND i.bo# = o.obj#
   AND oi.obj# = i.obj#
   AND ic.obj# = i.obj#
   AND ic.bo# = i.bo#
   AND ic.col# = c.col#
   AND c.col# > 0
   AND c.obj# = ct.obj# (+)
   AND c.col# = ct.col# (+)
   AND ct.toid = ot.oid$ (+)
   AND NOT EXISTS (SELECT 'x'
                     FROM sys.cdef$ cd,
			  sys.ccol$ cc,
			  sys.con$ co
                    WHERE cc.obj# = c.obj#
                      AND cc.col# = c.col#
                      AND cc.con# = cd.con#
                      AND co.con# = cd.con#
                      AND co.name = oi.name
                      AND cd.type# = 2)
       UNION
SELECT c.col#,
       c.name,
       decode(c.null$, 0, '', '*') n,
       decode(c.type#, 1, decode(c.charsetform, 2, 'NVARCHAR2(', 'VARCHAR2(')
               || to_char(c.length) || ')',
               2, decode(c.precision#,
                          126, 'FLOAT',
                          'NUMBER' || decode(c.scale, NULL, '',
                                              '(' || to_char(nvl(c.precision#,
								  (c.length - 3) * 2))
                                              || decode(c.scale, 0, ')',
							 ',' || to_char(c.scale)
                                                         || ')'))),
               8, 'LONG',
               9, decode(c.charsetform, 2, 'NCHAR(', 'VARCHAR(')
               || to_char(c.length) || ') VARYING',
               12, 'DATE',
               23, 'RAW' || '(' || to_char(c.length) || ')',
               24, 'LONG RAW',
               69, 'ROWID',
               96, decode(c.charsetform, 2, 'NCHAR(', 'CHAR(')
               || to_char(c.length) || ')',
               105, 'MLSLABEL',
               106, 'MLSLABEL',
               111, ot.name || '(REF)',
               112, decode(c.charsetform, 2, 'NCLOB', 'CLOB'),
               113, 'BLOB',
               114, 'BFILE',
               115, 'CFILE',
               121, ot.name,
               122, ot.name,
               123, ot.name,
               to_char(c.type#)) TYPE,
       '*** IDX ' || oi.name || '(C) ' || to_char(ic.pos#)
       || '/' || to_char(i.cols),
       3
  FROM sys.obj$ o,
       sys.user$ u,
       sys.tab$ t,
       sys.col$ c,
       sys.coltype$ ct,
       sys.obj$ ot,
       sys.ind$ i,
       sys.obj$ oi,
       sys.icol$ ic,
       sys.clu$ cl,
       sys.col$ clc
 WHERE u.name = decode(instr('&object', '.'), 0, USER,
			upper(substr('&object', 1, instr('&object', '.') - 1)))
   AND o.name = upper(substr('&object', instr('&object', '.') + 1))
   AND u.user# = o.owner#
   AND o.obj# = c.obj#
   AND c.col# > 0
   AND c.obj# = ct.obj# (+)
   AND c.col# = ct.col# (+)
   AND ct.toid = ot.oid$ (+)
   AND o.obj# = t.obj#
   AND t.bobj# = cl.obj#
   AND clc.obj# = cl.obj#
   AND clc.segcol# = c.segcol#
   AND i.bo# = cl.obj#
   AND oi.obj# = i.obj#
   AND ic.obj# = i.obj#
   AND ic.bo# = i.bo#
   AND ic.col# = clc.col#
       UNION
SELECT c.col#,
       c.name,
       decode(c.null$, 0, '', '*') n,
       decode(c.type#, 1, decode(c.charsetform, 2, 'NVARCHAR2(', 'VARCHAR2(')
               || to_char(c.length) || ')',
               2, decode(c.precision#,
                          126, 'FLOAT',
                          'NUMBER' || decode(c.scale, NULL, '',
                                              '(' || to_char(nvl(c.precision#,
								  (c.length - 3) * 2))
                                              || decode(c.scale, 0, ')',
							 ',' || to_char(c.scale)
                                                         || ')'))),
               8, 'LONG',
               9, decode(c.charsetform, 2, 'NCHAR(', 'VARCHAR(')
               || to_char(c.length) || ') VARYING',
               12, 'DATE',
               23, 'RAW' || '(' || to_char(c.length) || ')',
               24, 'LONG RAW',
               69, 'ROWID',
               96, decode(c.charsetform, 2, 'NCHAR(', 'CHAR(')
               || to_char(c.length) || ')',
               105, 'MLSLABEL',
               106, 'MLSLABEL',
               111, ot.name || '(REF)',
               112, decode(c.charsetform, 2, 'NCLOB', 'CLOB'),
               113, 'BLOB',
               114, 'BFILE',
               115, 'CFILE',
               121, ot.name,
               122, ot.name,
               123, ot.name,
               to_char(c.type#)) TYPE,
       ' ', 0
  FROM sys.obj$ o,
       sys.user$ u,
       sys.col$ c,
       sys.coltype$ ct,
       sys.obj$ ot
 WHERE u.name = decode(instr('&object', '.'), 0, USER,
			upper(substr('&object', 1, instr('&object', '.') - 1)))
   AND o.name = upper(substr('&object', instr('&object', '.') + 1))
   AND u.user# = o.owner#
   AND o.obj# = c.obj#
   AND c.col# > 0
   AND c.obj# = ct.obj# (+)
   AND c.col# = ct.col# (+)
   AND ct.toid = ot.oid$ (+)
   AND NOT EXISTS (SELECT 'x'
                     FROM sys.icol$ ic
                    WHERE ic.bo# = c.obj#
                      AND ic.col# = c.col#
			  UNION
                   SELECT 'x'
                     FROM sys.tab$ t,
			  sys.clu$ cl,
			  sys.col$ clc
                    WHERE t.obj# = o.obj#
                      AND t.bobj# = cl.obj#
                      AND clc.obj# = cl.obj#
                      AND clc.segcol# = c.segcol#
			  UNION
                   SELECT 'x'
                     FROM sys.com$ cm
                    WHERE cm.obj# = c.obj#
                      AND cm.col# = c.col#)
       UNION
SELECT c.col#,
       c.name,
       decode(c.null$, 0, '', '*') n,
       decode(c.type#, 1, decode(c.charsetform, 2, 'NVARCHAR2(', 'VARCHAR2(')
               || to_char(c.length) || ')',
               2, decode(c.precision#,
                          126, 'FLOAT',
                          'NUMBER' || decode(c.scale, NULL, '',
                                              '(' || to_char(nvl(c.precision#,
								  (c.length - 3) * 2))
                                              || decode(c.scale, 0, ')',
							 ',' || to_char(c.scale)
                                                         || ')'))),
               8, 'LONG',
               9, decode(c.charsetform, 2, 'NCHAR(', 'VARCHAR(')
               || to_char(c.length) || ') VARYING',
               12, 'DATE',
               23, 'RAW' || '(' || to_char(c.length) || ')',
               24, 'LONG RAW',
               69, 'ROWID',
               96, decode(c.charsetform, 2, 'NCHAR(', 'CHAR(')
               || to_char(c.length) || ')',
               105, 'MLSLABEL',
               106, 'MLSLABEL',
               111, ot.name || '(REF)',
               112, decode(c.charsetform, 2, 'NCLOB', 'CLOB'),
               113, 'BLOB',
               114, 'BFILE',
               115, 'CFILE',
               121, ot.name,
               122, ot.name,
               123, ot.name,
               to_char(c.type#)) TYPE,
       '*** FK --> ' || o2.name || '(' || c2.name || ') '
       || ltrim(to_char(cc1.pos#))
       || '/'
       || ltrim(to_char(cd1.cols)) , 2
  FROM sys.obj$ o,
       sys.user$ u,
       sys.col$ c,
       sys.coltype$ ct,
       sys.obj$ ot,
       sys.cdef$ cd1,
       sys.ccol$ cc1,
       sys.ccol$ cc2,
       sys.obj$ o2,
       sys.col$ c2
 WHERE u.name = decode(instr('&object', '.'), 0, USER,
			upper(substr('&object', 1, instr('&object', '.') - 1)))
   AND o.name = upper(substr('&object', instr('&object', '.') + 1))
   AND o.obj# = c.obj#
   AND c.col# > 0
   AND c.obj# = ct.obj# (+)
   AND c.col# = ct.col# (+)
   AND ct.toid = ot.oid$ (+)
   AND cd1.obj# = o.obj#
   AND cd1.con# = cc1.con#
   AND cc1.obj# = c.obj#
   AND cc1.col# = c.col#
   AND cd1.type# = 4
   AND cc2.con# = cd1.rcon#
   AND cc2.obj# = cd1.robj#
   AND cc2.obj# = o2.obj#
   AND cc2.obj# = c2.obj#
   AND cc2.col# = c2.col#
   AND cc1.pos# = cc2.pos#
       UNION
SELECT c.col#,
       c.name,
       decode(c.null$, 0, '', '*') n,
       decode(c.type#, 1, decode(c.charsetform, 2, 'NVARCHAR2(', 'VARCHAR2(')
               || to_char(c.length) || ')',
               2, decode(c.precision#,
                          126, 'FLOAT',
                          'NUMBER' || decode(c.scale, NULL, '',
                                              '(' || to_char(nvl(c.precision#,
								  (c.length - 3) * 2))
                                              || decode(c.scale, 0, ')',
							 ',' || to_char(c.scale)
                                                         || ')'))),
               8, 'LONG',
               9, decode(c.charsetform, 2, 'NCHAR(', 'VARCHAR(')
               || to_char(c.length) || ') VARYING',
               12, 'DATE',
               23, 'RAW' || '(' || to_char(c.length) || ')',
               24, 'LONG RAW',
               69, 'ROWID',
               96, decode(c.charsetform, 2, 'NCHAR(', 'CHAR(')
               || to_char(c.length) || ')',
               105, 'MLSLABEL',
               106, 'MLSLABEL',
               111, ot.name || '(REF)',
               112, decode(c.charsetform, 2, 'NCLOB', 'CLOB'),
               113, 'BLOB',
               114, 'BFILE',
               115, 'CFILE',
               121, ot.name,
               122, ot.name,
               123, ot.name,
               to_char(c.type#)) TYPE,
       '*** FK <- ' || o2.name || '(' || c2.name || ') '
       || ltrim(to_char(cc2.pos#))
       || '/'
       || ltrim(to_char(cd2.cols)) , 2
  FROM sys.obj$ o,
       sys.user$ u,
       sys.col$ c,
       sys.coltype$ ct,
       sys.obj$ ot,
       sys.cdef$ cd2,
       sys.ccol$ cc1,
       sys.ccol$ cc2,
       sys.obj$ o2,
       sys.col$ c2
 WHERE u.name = decode(instr('&object', '.'), 0, USER,
			upper(substr('&object', 1, instr('&object', '.') - 1)))
   AND o.name = upper(substr('&object', instr('&object', '.') + 1))
   AND cd2.robj# = o.obj#
   AND cd2.rcon# = cc1.con#
   AND cc1.obj# = o.obj#
   AND cc1.col# = c.col#
   AND o.obj# = c.obj#
   AND c.col# > 0
   AND c.obj# = ct.obj# (+)
   AND c.col# = ct.col# (+)
   AND ct.toid = ot.oid$ (+)
   AND cd2.type# = 4
   AND cd2.obj# = o2.obj#
   AND cc2.obj# = o2.obj#
   AND cc2.con# = cd2.con#
   AND cc2.obj# = c2.obj#
   AND cc2.col# = c2.col#
   AND cc1.pos# = cc2.pos#
 ORDER BY 1, 6;
SET heading on
SET feedback on
SET timing on
@login"

  "*SQL used from `sqlplus-desc-tab' function."
  :group 'oracle
  :type 'string)

(defcustom sqlplus-desc-query
   "SET define on
SET echo off
SET recsep off
SET linesize 60
prompt &object
DESC &object
SET linesize 10000"

  "*SQL used from `sqlplus-desc' function."
  :group 'oracle
  :type 'string)


(defvar sqlplus-startup-message
  (concat 
   "Emacs SQL*Plus Interpreter:  by Stewart Bryson of Transcendent Data, Inc.\n"
   "Based on sql-mode.el written by Jim Lange of Oracle Corporation.\n"
   "Enhancements by Thomas Miller to original version are included here.\n"
   "_________________________________________________________________________\n")
  "Message displayed when \\[sqlplus] is executed.")

(defvar sqlplus-last-output-start nil
  "In a sqlplus-mode buffer, marker for beginning of last batch of output.")

(defvar sqlplus-prompt-re nil
  "In a sqlplus-mode buffer, string containing prompt text.")

(defvar sqlplus-last-process-buffer nil
  "A file in oracle-mode remembers the last buffer entered.")

(defvar sqlplus-continue-pattern "^\\([0-9][0-9]:[0-9][0-9]:[0-9][0-9] \\)?[ 0-9][ 0-9][0-9][* \t][ \t]*\\|     "
  "In a sqlplus-mode buffer, regular expression for continuation line prompt.")

(defvar sqlplus-stack-pointer 0
  "Current command recalled from history of commands.")

(defvar sqlplus-tab-width nil
  "Width of the tab for sqlplus buffer.")

(defvar sqlplus-tab-stop-list nil
  "List of stops for sqlplus buffer.")

(defvar sqlplus-mode-map nil
  "Mode-map used for sqlplus-mode.")

(defvar sqlplus-lins-filename-ext "\\.lin$"
  "*Regular expression that matches the filename of a lins file.")

;;;=============================================================
;;; C. Variables defining casing options
;;;=============================================================

;;; Here we are using "SQL" to identify those commands that will be
;;; aligned with the end of the command word:
;;; 
;;;       SELECT tt
;;;         FROM yyy
;;;        WHERE ccc = ddd
;;;          AND dd = ee;
;;; 
;;; and "PL/SQL" to identify those commands that will be indented by a
;;; fixed amount like this:
;;; 
;;; IF x = y THEN
;;;    p := q;
;;; ELSE
;;;    c := d;
;;; END IF;
;;; 
;;; Each logical level is indented oracle-plsql-basic-offset spaces with respect to the
;;; previous one.
;;;
;;; "SQLPLUS" identifies commands that are not indented at all
;;;


(defcustom oracle-case-keyword-function 'upcase-word
  "*Function used to adjust the case of keywords.
It may be `downcase-word', `upcase-word' or `capitalize-word'."
  :type 'function
  :group 'oracle)

(defcustom oracle-base-case-function 'downcase-word
  "*Function used to adjust the case of unquoted, non-key words.
It may be `downcase-word', `upcase-word' or `capitalize-word'."
  :type 'function
  :group 'oracle)


(defcustom oracle-auto-case-flag t
  "*Non-nil means automatically changes case of keyword while typing.
Casing is done according to `oracle-case-keyword-function', so
long as a string matching `oracle-protect-line-re' is not found in
the line."
  :type 'boolean
  :group 'oracle )

(defcustom oracle-protect-line-re "\\-\\->>"
  "*Protect the line from auto-indentation.
If `oracle-auto-case-flag'  and/or `oracle-auto-indent-flag'
is non-nil, and a string matching this re is found in the line,
the line is not indented."
  :type 'string
  :group 'oracle)

;;;
;;; SQL*Plus variables
;;;

(defcustom sqlplus-cmd-list
  '( "accept" "break" "btitle" "clear" "column" "col" "compute" "define"
     "desc" "describe" "exit" "edit" "pause" "prompt" "purge" "quit" "set" 
     "show" "spo" "spool" "ttitle" "variable" "whenever")
  "*List of SQLPLUS commands, recognized at the start of a line only.
The rest of the line is unchanged by casing and indentation functions.

Changes will not take effect until oracle.el is recompiled."
  :type '(repeat string)
  :group 'oracle )


(defvar sqlplus-cmd-re nil
  "*Regular expression for start of sqlplus commands.
Created at compilation by `regexp-opt'.")

;; sqlplus keys are only recognized as commands if they start a line
;;     (no blanks before)

(if sqlplus-cmd-re
    ()
  (setq sqlplus-cmd-re
	(eval-when-compile
	  (concat "^\\(\\(" sqlplus-prompt " \\)?\\(\\(?:!\\|@\\|\\<"
		  (regexp-opt sqlplus-cmd-list 't) "\\).*\\)\\)"))))


(defvar sqlplus-keyword-re nil
  "*Regular expression for a sqlplus keyword.
Created at compilation by `regexp-opt'.")

(if sqlplus-keyword-re
    ()
  (setq sqlplus-keyword-re
	(eval-when-compile
	  (concat "^\\<"
		  (regexp-opt sqlplus-cmd-list t)  "\\>" ))))


;;;
;;; SQL variables
;;;

;;; keywords

(defcustom oracle-sql-keyword-list
  '( "admin" "after" "allocate" "analyze" "archive" "archivelog"
     "avg" "backup" "become" "before" "block" "body" "cache" 
     "cancel" "cascade" "change" "checkpoint" "commit" "compile"
     "constraint" "constraints" "contents" "continue" "controlfile"
     "cycle" "database" "datafile" "dba" "disable" "dismount" "double" 
     "dump" "each" "enable" "escape" "events" "except" "exec" "execute"
     "explain" "extent" "externally" "false" "fetch" "flush" "force"
     "foreign" "freelist" "freelists" "function" "groups" "including" 
     "initrans" "instance" "key" "lag" "layer" "link" "lists" "logfile" 
     "manage" "manual" "matched" "max" "maxdatafiles" "maxinistances"
     "maxlogfiles" "maxloghistory" "maxlogmembers" "maxtrans" "maxvalue" 
     "min" "minextents" "minvalue" "mount" "new" "next" "noarchivelog" 
     "nocache" "nocycle" "nomaxvalue" "nominvalue" "none" "noorder" 
     "noresetlogs" "normal" "nosort" "off" "old" "only" "optimal" "out" 
     "over" "own" "package" "parallel" "pctincrease" "pctused" "plan" "pragma" 
     "precision" "primary" "procedure" "private" "profile" "quota" "raise" 
     "read" "recover" "references" "referencing" "resetlogs" "restrict_references"
     "restricted" "returning" "reuse" "rnds" "rnps" "rollback" "role" "roles"
     "savepoint" "schema" "scn" "section" "segment" "sequence" "shared" 
     "snapshot" "some" "sort" "sqlcode" "sqlerror" "statement_id" "statistics" 
     "stop" "storage" "subtype" "sum" "switch" "system" "tables" "tablespace" 
     "temporary" "thread" "time" "tracing" "transaction" "triggers" "true" 
     "truncate" "under" "unlimited" "until" "use" "using" "when"
     "wnds" "wnps" "work" "write")
  "*List of SQL keywords.
The case of these keywords is set by the function `oracle-case-keyword-function'.

This function is called  by any of the functions that adjust case.
If `oracle-auto-case-flag' is t it is invoked when any end-of-word
character is typed.

The face defaults to font-lock-keyword-face if font-lock mode is on.

Changes will not take effect until oracle.el is recompiled."
  :type '(repeat string)
  :group 'oracle )

(defvar oracle-sql-keyword-re nil
  "Regular expression for Oracle keywords.")

(if oracle-sql-keyword-re
    ()
  (setq oracle-sql-keyword-re
	(eval-when-compile
	  (concat "\\<"
		  (regexp-opt oracle-sql-keyword-list t) "\\>" ))))


(defcustom oracle-sql-warning-word-list
  '( "cursor_already_open" "dup_val_on_index" "exception" "invalid_cursor"
     "invalid_number" "invalid_filename" "login_denied" "no_data_found" "not_logged_on"
     "notfound" "others" "pragma" "program_error" "storage_error"
     "timeout_on_resource" "too_many_rows" "transaction_backed_out"
     "value_error" "zero_divide")
  "*List of Oracle warning words for exception handling."
  :type '(repeat string)
  :group 'oracle )


(defvar oracle-sql-warning-word-re nil
  "Regular expression for Oracle keywords.")

(if oracle-sql-warning-word-re
    ()
  (setq oracle-sql-warning-word-re
	(eval-when-compile
	  (concat "\\<"
		  (regexp-opt oracle-sql-warning-word-list t) "\\>" ))))


(defcustom oracle-sql-reserved-word-list
  '( "access" "add" "all" "alter" "and" "any" "as" "asc" "audit" 
     "between" "bitmap" "by" "check" "cluster" "column" "comment" "compress"
     "connect" "create" "current" "current_timestamp" "default" "delete" "desc" "distinct" 
     "drop" "else" "exclusive" "exists" "file" "float" "for" "from" "grant" 
     "group" "having" "identified" "immediate" "in" "increment" "index" 
     "initial" "insert" "intersect" "into" "is" "join" "level" "like" "local" "lock" 
     "long" "maxextents" "merge" "minus" "mode" "model" "modify" "noaudit" "nocompress" 
     "not" "nowait" "number" "null" "of" "offline" "on" "option" "or" 
     "order" "privileges" "online" "pctfree" "prior" "public" "raw" "regexp_like"
     "rename" "resource" "revoke" "row" "rowlabel" "rownum" "rows" "select" 
     "session" "set" "share" "size" "start" "successful" "synonym" "sysdate"
     "table" "then" "to" "trigger" "union" "unique" "update" "user" "uid" 
     "validate" "values" "view" "where" "whenever" "with")
  "*List of Oracle reserved words."
  :type '(repeat string)
  :group 'oracle )


(defvar oracle-sql-reserved-word-re nil
  "Regular expression for Oracle reserved words.")

(if oracle-sql-reserved-word-re
    ()
  (setq oracle-sql-reserved-word-re
	(eval-when-compile
	  (concat "\\<"
		  (regexp-opt oracle-sql-reserved-word-list t) "\\>" ))))



;;; built-in functions

(defcustom oracle-sql-function-list
  '("abs" "add_months" "ascii" "avg" "ceil" "chartorowid" "chr" "concat"
    "convert" "cos" "cosh" "count" "currval" "decode" "dump" "exp" "floor"
    "glb" "greatest" "greatest_lb" "hextoraw" "initcap" "instr" "instrb"
    "last_day" "least" "least_ub" "length" "lengthb" "ln" "log" "lower"
    "lpad" "ltrim" "lub" "max" "min" "mod" "months_between" "new_time"
    "next_day" "nextval" "nls_initcap" "nls_lower" "nls_upper" "nlssort"
    "nvl" "nvl2" "power" "rawtohex" "rawtonhex" "regexp_instr" "regexp_replace" 
    "regexp_substr" "replace" "round" "rowidtochar" "rpad" "rtrim" "sign" 
    "sin" "sinh" "soundex" "sqlcode" "sqlerrm" "sqrt" "stddev" "sum" "substr" 
    "substrb" "tan" "tanh" "to_char" "to_date" "to_label" "to_multi_byte"
    "to_number" "to_single_byte" "translate" "trim" "trunc" "uid" "upper"
    "userenv" "variance" "vsize")
  "*List of sql built-in functions.
Used for font-lock mode, but not for casing/indentation.
Changes will not take effect until oracle.el is recompiled."
  :type '(repeat string)
  :group 'oracle )

(defvar oracle-sql-function-re nil
  "Regular expression for SQLPLUS keywords.

Created at compilation from `oracle-sql-function-list' by `regexp-opt'.")

(if oracle-sql-function-re
    ()
  (setq oracle-sql-function-re
	(eval-when-compile
	  (concat "\\<"
		  (regexp-opt oracle-sql-function-list  t) "\\> *(" ))))


;;; data types
(defcustom oracle-sql-type-list
  '( "binary_integer" "blob" "boolean" "char" "character" "clob"
     "constant" "date" "decimal"  "int" "integer"  "number" "rowid"
     "%rowtype" "timestamp" "%type" "varchar" "varchar2" "pls_integer")
  "*List of SQL type-names.
If `oracle-auto-case-flag' is t the case of these keywords is
automatically changed by the function `oracle-case-keyword-function'.
Changes will not take effect until oracle.el is recompiled."
  :type '(repeat string)
  :group 'oracle )

(defvar  oracle-sql-type-re nil
  "Regular expression for SQL type-names.
If `oracle-auto-case-flag' is t the case of these keywords is
automatically changed by the function `oracle-case-keyword-function'.

In `font-lock-mode', defaults to font-lock-type-face.

Created at compilation by `regexp-opt'.")

(if oracle-sql-type-re
    ()
  (setq oracle-sql-type-re
	(eval-when-compile
	  (concat "\\<"
		  (regexp-opt oracle-sql-type-list t) "\\>" ))))

;;; commands

;;  SQL command keywords are not recognized for indentation purposes unless
;;    they occur as the first non-blank characters in a line.
;;
;;  "select" is an exception to this, and is recognized inside another
;;     statement and not only at the start of a line
;;
;;  "(" is also a command-start for indentation purposes

(defcustom oracle-sql-cmd-re
  "\\(^[ \t]*\\(?:alter +table\\|alter +session\\|analyze\\|audit\\|comment\\|commit\\|cursor\\|create +table\\|create +\\(unique \\|bitmap \\)? *index\\|delete\\|drop\\|exec\\|fetch\\|grant\\|insert +into\\|merge +into\\|lock\\|noaudit\\|numeric\\|pragma\\|public\\|rename\\|revoke\\|rollback\\|savepoint\\|truncate\\)\\>\\)\\|(\\|\\<update\\|select\\>"
  "*Regular expression for the start of an SQL command.
Controls SQL-style indentation when appearing at the start of a line."
  :type 'string
  :group 'oracle )


;;
;; Before oracle-sql-alist is used, all multiple
;; spaces in the command expression are reduced to single spaces.
;;
(defcustom oracle-sql-alist
  '(
    ("select" . "\\<\\(?:and\\|connect\\|from\\|left\\|right\\|full\\|outer\\|join\\|and\\|group\\|into\\|having\\|level\\|or\\|order\\|prior\\|select\\|start\\|where\\|model\\|union\\)\\>" )
    ("alter session" . "\\<set\\>")
    ("fetch"         . "\\<into\\>")
    ("update"        . "\\<\\(?:and\\|or\\|set\\|where\\)\\>")
    ("delete"        . "\\<\\(?:and\\|or\\|where\\)\\>")
    ("create table"  . "\\<select\\>")
    ("create index"  . "\\<on\\>")
    ("create unique index"  . "\\<on\\>")
    ("merge into"    . "\\<\\(?:using\\|on\\|when \\(matched\\)\\|\\(not matched\\)\\)\\>")
    ("insert into"   . "\\<\\(?:values|select\\)\\>")
    ("("             . ")"))
  "AList of regular expressions for sub-parts of SQL commands.
The car is the main SQL command, and the cdr is the regular
expression for sub-parts of the command.

These parts are indented by oracle-indent-line so that they
right-align with the end of the main command."
  :type 'alist
  :group 'oracle )
 
(defcustom oracle-command-end-re ";\\|^\\/\\s-*$"
  "*Regular expression for the end of an sql command."
  :type 'string
  :group 'oracle)


;;;
;;; PLSQL keywords
;;;

(defcustom oracle-plsql-keyword-list
  '( "authid" "begin" "case" "close" "current_user" "cursor" "declare" "else" "elsif" "end" "exception" "exit"
     "exit when" "for" "if" "into" "loop" "on" "open" "pipelined" "record" "replace"
     "return" "then" "type" "while" "when")
  "*List of PL/SQL keywords.
The case of these keywords is set by the function `oracle-case-keyword-function'.

This function is called  by any of the functions that adjust case.
If `oracle-auto-case-flag' is t it is invoked when any end-of-word
character is typed.

The face defaults to font-lock-keyword-face if font-lock mode is on.

Changes will not take effect until oracle.el is recompiled."
  :type '(repeat string)
  :group 'oracle )

(defvar oracle-plsql-keyword-re nil
  "Regular expression for PL/SQL keywords.

Created at compilation by `regexp-opt' from `oracle-plsql-keyword-list'." )

(if oracle-plsql-keyword-re
    ()
  (setq oracle-plsql-keyword-re
	(eval-when-compile
	  (concat "\\<"
		  (regexp-opt oracle-plsql-keyword-list t) "\\>"))))

;; 
;; Only PLSQL commands that are the first non-blank characters in the line
;; are recognized for indentation.
;;
(defcustom oracle-plsql-cmd-re
  "^[ \t]*\\<\\(?:if\\|loop\\|begin\\|declare\\|for\\|while\\|exception\\|when\\|function\\|procedure\\|create\\(?:\\s-+or\\s-+replace\\)?\\(?:\\s-+\\)package\\|create\\(?:\\s-+or\\s-+replace\\)?\\(?:\\s-+\\)procedure\\|create\\(?:\\s-+or\\s-+replace\\)?\\s-+function\\|create\\(?:\\s-+or\\s-+replace\\)?\\s-+trigger\\)\\>"
  "*Regular expression for the start of a PL/SQL command."
  :type 'string
  :group 'oracle )


;;
;; Note that before oracle-plsql-cmd-re-alist is used, all multiple
;; spaces in the command expression are reduced to single spaces.
;;
(defcustom oracle-plsql-alist
  '(
    ("for" . "\\<\\(?:loop\\|end\\s-+loop\\)\\>")
    ("loop" . "\\<\\(?:end\\s-+loop\\)\\>")
    ("while" . "\\<loop\\>")
    ("if" . "\\<\\(?:else\\|elsif\\|then\\|end\\s-+if\\)\\>")
    ("case" . "\\<\\(?:else\\|when\\|then\\|end\\)\\>")
    ("begin" . "\\<exception\\|end\\>")
    ("declare" . "\\<begin\\>")
    ("create procedure" . "\\<\\(?:as\\|begin\\)\\>")
    ("create function" . "\\<\\(?:is\\|as\\|begin\\)\\>")
    ("function" . "\\<\\(?:is\\|as\\|begin\\)\\>")
    ("procedure" . "\\<\\(?:is\\|as\\|begin\\)\\>")
    ("create trigger" . "\\<\\(?:is\\|as\\|on\\|before\\|after\\|for\\|when\\|begin\\)\\>")
    ("create or replace procedure" . "\\<\\(?:as\\|procedure\\|begin\\)\\>")
    ("create or replace function" . "\\<\\(?:is\\|as\\|begin\\)\\>")
    ("create or replace trigger" . "\\<\\(?:is\\|as\\|on\\|before\\|after\\|for\\s-+each\\s-+row\\|declare\\|when\\|begin\\)\\>")
    ("create package" . "\\<as\\|is\\|begin\\|end\\>")
    ("create or replace package" . "\\<as\\|is\\|begin\\|end\\>"))
  "*Regular expressions for sub-parts of PL/SQL commands.
The car is the main SQL command, and the cdr is the regular
expression for sub-parts of the command.
These parts are indented by oracle-indent-line to the same level
as the parent command."
  :type 'alist
  :group 'oracle)

(defcustom oracle-plsql-cmd-part-re
  "\\<\\(?:else\\|elsif\\|exception\\|end\\|on\\|before\\|after\\|when\\|for\\s-+each\\s-+row\\)\\>"
  "*Regular expression for a sub-part of a PL/SQL command."
  :type 'list
  :group 'oracle )

(defcustom oracle-plsql-cmd-end-re
  "\\<end\\>"
  "*Regular expression for recognizing end of PL/SQL commands."
  :type 'string
  :group 'oracle )


;;;=============================================================
;;; D. Variables defining indentation options
;;;=============================================================

(defcustom oracle-plsql-basic-offset 3
  "*Amount of indentation for PL/SQL statements."
  :type 'number
  :group 'oracle)

(defcustom oracle-auto-indent-flag t
  "*Non-nil means lines are indented as they are typed."
  :type 'boolean
  :group 'oracle )

(defcustom oracle-tab-binding 'indent-relative
  "*Function invoked by TAB when indentation is not required.
ie when oracle-auto-indent is null, or at any time if the cursor is after the
first word in the line."
  :type 'function
  :group 'oracle)

(defvar oracle-mode-comments nil
  "List of start and end positions of comments in a particular SQL buffer.")

(defvar oracle-mode-rebuild-comments t
  "If t, rebuild the comment list the next time oracle-mode-build-comments is
run.")

(defvar oracle-mode-rem-comment-re "^rem"
  "*Regular expression matching a REM-style comment.")

;;;=============================================================
;;; E. Variables for tkprof
;;;=============================================================

(defcustom tkprof-directory oracle-file-directory
  "Location of where tkprof files are written to, and trace files are copied to if dired buffer is remote"
  :group 'oracle
  :type 'string)

(defcustom tkprof-waits
  "yes"
  "*Value for the waits parameter of tkprof."
  :type 'string
  :group 'oracle )

(defcustom tkprof-sys
  "no"
  "*Value for the sys parameter of tkprof."
  :type 'string
  :group 'oracle )

(defcustom tkprof-aggregate
  "no"
  "*Value for the aggregate parameter of tkprof."
  :type 'string
  :group 'oracle )

(defcustom tkprof-sort
  "prsela,exeela,fchela"
  "*Value for the aggregate parameter of tkprof."
  :type 'string
  :group 'oracle )

(defcustom tkprof-statement-re 
  "^\\(select\\|insert\\|update\\|delete\\|create\\)"
  "*Regular expression for for constructing a statement map."
  :type 'string
  :group 'oracle)

(defcustom tkprof-statement-nav-ratio 3
  "What ratio of the current frame should be used for the statement-map"
  :group 'oracle
  :type 'number)

(defcustom tkprof-statement-nav-nlines 1
  "Value for nlines to pass to `occur'"
  :group 'oracle
  :type 'number)

;;;=============================================================
;;; E. Variables for plsql wrap
;;;=============================================================

;; initialize abbreviations

(defvar oracle-mode-abbrev-table nil
  "*Abbreviations for oracle and sqlplus modes")

(define-abbrev-table 'oracle-mode-abbrev-table ())
(let ((abbrevs-changed nil))
  (define-abbrev oracle-mode-abbrev-table  "d"   "describe" nil)
  (define-abbrev oracle-mode-abbrev-table  "s"   "select"   nil)
  (define-abbrev oracle-mode-abbrev-table  "f"   "from"     nil)
  (define-abbrev oracle-mode-abbrev-table  "w"   "where"    nil)
  (define-abbrev oracle-mode-abbrev-table  "o"   "order by" nil)
  (define-abbrev oracle-mode-abbrev-table  "l"   "like"     nil)
  (define-abbrev oracle-mode-abbrev-table  "i"   "in ("     nil)
  (define-abbrev oracle-mode-abbrev-table  "g"   "group by" nil)
  (define-abbrev oracle-mode-abbrev-table  "h"   "having"   nil)
  (define-abbrev oracle-mode-abbrev-table  "n"   "not"      nil))


(require 'easymenu)
   
(defvar oracle-keyword-re
  (concat  "\\(?:" oracle-sql-keyword-re   "\\|"
	   ;; oracle-sql-function-re  "\\|"
	   oracle-sql-type-re  "\\|"
	   oracle-plsql-keyword-re "\\|"
	   oracle-sql-reserved-word-re "\\|"
	   sqlplus-keyword-re "\\)")
  "regular expression for any sql, plsql or sqlplus keyword.
Derived from oracle-sql-type-re, oracle-plsql-keyword-re and
sqlplus-keyword-re. ")

(defvar oracle-mode-syntax-table nil
  "*Syntax table to be used for editing SQL source code.")


(defun oracle-create-syntax-table ()
  "Create the syntax table for Oracle Mode."
  (setq oracle-mode-syntax-table (make-syntax-table))
  (set-syntax-table  oracle-mode-syntax-table)

  ;; define string brackets
  (modify-syntax-entry ?\' "\"" oracle-mode-syntax-table)
  (modify-syntax-entry ?\" "\"" oracle-mode-syntax-table)

  (modify-syntax-entry ?%  "w" oracle-mode-syntax-table)
  (modify-syntax-entry ?\# "w" oracle-mode-syntax-table)
  (modify-syntax-entry ?:  "." oracle-mode-syntax-table)
  (modify-syntax-entry ?\; "." oracle-mode-syntax-table)
  (modify-syntax-entry ?&  "." oracle-mode-syntax-table)
  (modify-syntax-entry ?\| "." oracle-mode-syntax-table)
  (modify-syntax-entry ?+  "." oracle-mode-syntax-table)
  (modify-syntax-entry ?*  "." oracle-mode-syntax-table)
  (modify-syntax-entry ?/  "." oracle-mode-syntax-table)
  (modify-syntax-entry ?=  "." oracle-mode-syntax-table)
  (modify-syntax-entry ?<  "." oracle-mode-syntax-table)
  (modify-syntax-entry ?>  "." oracle-mode-syntax-table)
  (modify-syntax-entry ?$  "w" oracle-mode-syntax-table)
  (modify-syntax-entry ?\[ "." oracle-mode-syntax-table)
  (modify-syntax-entry ?\] "." oracle-mode-syntax-table)
  (modify-syntax-entry ?\{ "." oracle-mode-syntax-table)
  (modify-syntax-entry ?\} "." oracle-mode-syntax-table)
  (modify-syntax-entry ?.  "." oracle-mode-syntax-table)
  (modify-syntax-entry ?\\ "." oracle-mode-syntax-table)
 
  (modify-syntax-entry ?\_ "w" oracle-mode-syntax-table)

  ;; a single hyphen is punctuation, but a double hyphen starts a comment
  (modify-syntax-entry ?-  ". 12" oracle-mode-syntax-table)
  (modify-syntax-entry ?/  ". 14" oracle-mode-syntax-table)
  (modify-syntax-entry ?*  ". 23" oracle-mode-syntax-table)

  ;; and \f and \n end a comment
  (modify-syntax-entry ?- ". 12b" oracle-mode-syntax-table)
  (modify-syntax-entry ?\n "> b"  oracle-mode-syntax-table)
  (modify-syntax-entry ?\f "> b"  oracle-mode-syntax-table)

  ;; define parentheses to match
  (modify-syntax-entry ?\( "()" oracle-mode-syntax-table)
  (modify-syntax-entry ?\) ")(" oracle-mode-syntax-table))

(defvar oracle-ret-binding nil
  "Variable to save key binding of RET when casing is activated.")

(defvar oracle-lfd-binding nil
  "Variable to save key binding of LFD when casing is activated.")

(defvar oracle-font-lock-keywords nil
  "Keywords for font-lock mode.")

;; SQLPLUS variables



;;;---------------------------------
;;; define keymaps and menus
;;;---------------------------------


(defvar oracle-mode-map
  (let ((oracle-mode-map (make-keymap)))
    (define-key oracle-mode-map "\177"     'backward-delete-char-untabify)
    (define-key oracle-mode-map "\C-c\C-c" 'oracle-reformat-region)
    (define-key oracle-mode-map "\C-c\C-v" 'oracle-indent-and-case-region)
    (define-key oracle-mode-map "\C-c\C-q" 'oracle-local-reformat-region)
    (define-key oracle-mode-map "\C-c\C-w" 'oracle-local-indent-and-case-region)
    (define-key oracle-mode-map "\C-c\C-p" 'oracle-local-indent-region)
    (define-key oracle-mode-map "\C-c\C-l" 'oracle-align-region-to-point)
    (define-key oracle-mode-map "\C-c\C-g" 'oracle-generate-group-by)
    (define-key oracle-mode-map "\C-c\C-w" 'oracle-plsql-wrap)
    (define-key oracle-mode-map "\C-c\C-n" 'oracle-plsql-navigator)
    (define-key oracle-mode-map "\C-c\C-v" 'oracle-variable-list)
    (define-key oracle-mode-map "\C-c:"    'oracle-comma-sep-list)
    (define-key oracle-mode-map "\C-c3"    'oracle-comma-sep-triple)
    (define-key oracle-mode-map "\C-c;"    'oracle-comma-sep-line)
    (define-key oracle-mode-map "\C-c\C-u" 'oracle-uncomment-region)
    (define-key oracle-mode-map "\C-c\C-f" 'oracle-fill-comment-paragraph-postfix)
    (define-key oracle-mode-map "\C-c\C-p" 'oracle-fill-comment-paragraph-prefix)
    (define-key oracle-mode-map "\t"       'oracle-indent-or-tab)
    (define-key oracle-mode-map "\C-c<"    'oracle-backtab)
    (define-key oracle-mode-map (kbd "C-c C-r") 'oracle-send-region)
    (define-key oracle-mode-map (kbd "C-c C-x") 'oracle-send-buffer)
    (define-key oracle-mode-map (kbd "C-c C-e") 'oracle-explain)
    (define-key oracle-mode-map (kbd "C-c C-a") 'oracle-autotrace)
    (define-key oracle-mode-map (kbd "C-c C-s") 'oracle-autotrace-explain)
    oracle-mode-map )
  "*Local keymap used for Oracle Mode.")

(easy-menu-define
  oracle-mode-menu oracle-mode-map
  "Menu for `oracle-mode'."
  '("Oracle"
    "--- Commands Affecting the Whole Buffer ---"
    ["auto case"                                   oracle-toggle-auto-case
     :style radio
     :selected  oracle-auto-case-flag ]
    ["auto indent"                                 oracle-toggle-auto-indent
     :style radio
     :selected   oracle-auto-indent-flag ]
    ["Indent and case buffer"                      oracle-reformat-buffer ]
    "--"
    "--- Commands Affecting the Region ---"
    ["Indent and case all words in region"         oracle-reformat-region   ]
    ["Indent and case keywords in region"          oracle-indent-and-case-region ]
    ["Indent region"                               indent-region ]
    ["Locally indent and case all words in region" oracle-local-reformat-region ]
    ["Locally indent and case keywords in region"  oracle-local-indent-and-case-region ]
    ["Locally indent region"                       oracle-local-indent-region ]
    ["Align region to its first column"            oracle-align-region-to-point]
    "--"
    "--- Commands for Executing in SQL-Plus ---"
    ["Send Region" oracle-send-region]
    ["Send Buffer" oracle-send-buffer]
    ["Explain Statement" oracle-explain]
    ["Autotrace Statement" oracle-autotrace]
    ["Autotrace Trace Only Statement" oracle-autotrace-explain]
    "--"
    "--- Generate code from the output of Oracle DESC ---"
    ["'where' clause for a table join"    oracle-where-list ]
    ["plsql list of variables"            oracle-variable-list ]
    ["comma-separated list 1 per line"    oracle-comma-sep-list ]
    ["comma-separated list 3 per line"    oracle-comma-sep-triple ]
    ["comma-separated list inline"        oracle-comma-sep-line ]
    "--"
    "--- Other Commands for Generating Code ---"
    ["Generate `Group By' clause (experimental)"  oracle-generate-group-by ]
    "--"
    "--- Commands for Formatting Comments ---"
    ["Comment region (--)"              comment-region ]
    ["Uncomment region (--)"            oracle-uncomment-region ]
    ["Fill comment paragraph (--)"       oracle-fill-comment-paragraph-prefix ]
    ["Fill comment paragraph (/*..*/)"   oracle-fill-comment-paragraph-postfix ]))


;;;;                  -------------------
;;;;                  ** 2. ORACLE-MODE **
;;;;                  -------------------

;;;###autoload
(defun oracle-mode()
  "A major mode for editing a mixture of SQLPLUS, SQL
and PL/SQL code.

With oracle-auto-indent-flag and oracle-auto-case-flag = t, text is
indented and keywords are (default upper-)cased as they are typed.
Lines containing a match for oracle-protect-line-re are not changed.

Functions are available for:

 1. Indenting and/or changing the case of regions or the whole buffer
    Indentation of a region may be done with respect to the entire buffer,
    or by treating the selected region in isolation.

 2. Commenting/uncommenting regions and filling comments

 3. manipulating the output of SQLPLUS `describe table' commands
    to generate:  lists of columns
                  'where' clauses
                  function argument lists
    These commands operate on a region consisting of lines of the form:

         COLUMN_NAME1    NOT NULL CHAR(5)
         COLUMN_NAME2             INTEGER
         COLUMN_NAME3             VARCHAR2(2000)
                                               ...... etc
         
 4. Generating the `Group By' clause of a select statement.  This is
    somewhat experimental, and the output should be checked.  It should still
    save a lot of typing when the select clause is long.

 5. Executing SQL code through SQL*Plus. sql-send-buffer and sql-send-region
    are commands that will send SQL*Plus commands defined in the current buffer
    to SQL*Plus to be executed.  Output is displayed in the *sqlplus* buffer 
    (which will open as separate window if it does not already exist).

    Entry to this mode calls the value of sqlplus-mode-hook with no args,
    if that value is non-nil.  Abbrev-mode is also enabled with the following
    abbreviations available by default:

        s  ->  Select
        f  ->  From
        w  ->  Where
        o  ->  Order By

    Use \\[list-abbrevs] for a full list.

    If the SQL statements to be executed contain variables prefixed with colons
    or INTO clauses, the colons are converted into ampersands and the INTO clauses
    are removed before being sent to SQL*Plus.  This provides compatibility with
    Pro*C, SQL*Report, and SQL*Forms (.inp files).  For example,

       SELECT SYSDATE + :days_added INTO :variable FROM SYSTEM.DUAL

    is converted to

       SELECT SYSDATE + &days_added FROM SYSTEM.DUAL

    and the user is prompted to enter the value of days_added.


This mode provided keywords of three types:

 1. SQL commands are indented to the level of the column after the
    end of the command:

    UPDATE mytable
      SET mycolumn = `xx'
    WHERE anothercolumn > 5;

    Most SQL command keywords are only recognized for indentation
    purposes if they occur as the first non-blank word in a line.
    'select' is the only exception to this. It is recognized inside
    another statement and not only at the start of a line.

    '(' is also an SQL command-start for indentation purposes.

 2. PL/SQL commands are indented as is usual in C-style programming languages:

    BEGIN
       IF x > y THEN
          dothis
       ELSE
          dothat
       END IF;
    END;

    The depth of an indentation step  is controlled by the variable
    oracle-plsql-basic-offset (default 3).

 3. SQLPLUS commands are recognized only if they start a line (*no* initial
    spaces allowed), and all text from the end of the command word to the end
    of the line is treated as comment - ie, is not auto-cased.

    eg:

    PROMPT Select the address
    COLUMN address format A9
"

  ;; Set up some special values for emacs variables
  (interactive)

  (kill-all-local-variables)

  (make-local-variable 'comment-start)
  (setq comment-start oracle-comment-prefix)

  ;; comment-end must be set because it may hold a wrong value if
  ;; this buffer had been in another mode before.
  (make-local-variable 'comment-end)
  (setq comment-end "")

  (make-local-variable 'comment-start-skip)
  ;; used by autofill, font-lock, etc
  (setq comment-start-skip
        "--+[ \t]*\\|\\/\\*[ \t]*\\|\\<rem[ \t]+\\|\\<prompt[ \t]+")

  (make-local-variable 'indent-line-function)
  (setq indent-line-function 'oracle-indent-line)

  (make-local-variable 'mark-even-if-inactive)
  ;; needed to avoid re-selecting for "desc table" functions
  (setq mark-even-if-inactive t)

  (set (make-local-variable 'comment-padding) 0)

  (make-local-variable 'parse-sexp-ignore-comments)
  ;; needed for paren balancing
  (setq parse-sexp-ignore-comments t)

  ;; the associated font-lock faces
  (make-local-variable 'font-lock-defaults)
  (setq oracle-font-lock-keywords
	(list
	 (list (concat sqlplus-cmd-re ".*$") 0 'font-lock-reference-face t)
	 ;;(list (concat oracle-comment-start-re ".*$") 0 'font-lock-comment-face t)
	 (cons oracle-plsql-keyword-re  'font-lock-keyword-face )
	 (cons oracle-sql-type-re  'font-lock-type-face )
	 (cons oracle-sql-keyword-re  'font-lock-function-name-face )
	 (cons oracle-sql-warning-word-re 'font-lock-warning-face)
	 (cons oracle-sql-reserved-word-re 'font-lock-keyword-face)
	 ;;(cons sqlplus-prompt 'font-lock-function-name-face)
	 (list oracle-sql-function-re 1 'font-lock-builtin-face )
	 ))


  (setq font-lock-defaults
	'(oracle-font-lock-keywords  nil t  nil nil ))

  (make-local-variable 'case-fold-search)

  ;; Oracle sql is case-insensitive
  (setq case-fold-search t)

  (make-local-variable 'fill-paragraph-function)
  (setq fill-paragraph-function 'oracle-fill-comment-paragraph)

  (setq major-mode 'oracle-mode)
  (setq mode-name "Oracle")

  (use-local-map oracle-mode-map)
  (easy-menu-add oracle-mode-menu  oracle-mode-map)

  (if oracle-mode-syntax-table
      (set-syntax-table oracle-mode-syntax-table)
    (oracle-create-syntax-table))

  (run-hooks 'oracle-mode-hook)

  (if (or oracle-auto-indent-flag oracle-auto-case-flag)
      (oracle-activate-keys)))		; END oracle-mode


;;;;         ----------------------------------------------
;;;;         ** 3. AUTO CASING AND INDENTATION FUNCTIONS **
;;;;         ----------------------------------------------

;;;------------------------
(defun oracle-activate-keys ()
  "Save original keybindings for ret/lfd.
When autocasing is activated, save the keybindings so
they can be called after the autocase function when
ret or lfd are typed."
;;;------------------------
  ;; the 'or ...' is there to be sure that the value will not
  ;; be changed again when SQL Mode is called more than once (MH)
  ;; 
  (or oracle-ret-binding
      (setq oracle-ret-binding (key-binding "\C-M")))
  (or oracle-lfd-binding
      (setq oracle-lfd-binding (key-binding "\C-j")))
  ;; call case/indent function after certain keys.
  (mapcar (function (lambda(key)
                      (define-key  oracle-mode-map
                        (char-to-string key)
			'oracle-case-indent-interactive)))
          '( ?& ?* ?( ?)  ?= ?+ ?[  ?]
                ?\\ ?| ?\; ?:  ?\" ?< ?,  ?\n 32 ?\r )))

;;;------------------------
(defun oracle-toggle-auto-case ()
  "Unset automatic keyword casing if it is set, otherwise set it."
;;;------------------------
  (interactive)
  (if oracle-auto-case-flag
      (setq oracle-auto-case-flag nil)
    (setq oracle-auto-case-flag t)))

;;;------------------------
(defun oracle-toggle-auto-indent ()
  "Unset automatic indentation if it is set, otherwise set it."
;;;------------------------
  (interactive)
  (if  oracle-auto-indent-flag
      (setq oracle-auto-indent-flag nil)
    (setq oracle-auto-indent-flag t)))

(defun oracle-toggle-indent-case ()
  "Unset automatic indentation if it is set, otherwise set it."
;;;------------------------
  (interactive)
(oracle-toggle-auto-indent)
(oracle-toggle-auto-case))

;;;------------------------
(defun oracle-indent-or-tab ()
  "Indent if in or before first word of line.
Otherwise call `oracle-tab-binding'.  This is the function invoked by TAB.

Do nothing if the line is protected by `oracle-protect-line-re'.
If point is before the first word in the line, call `oracle-indent-line'.
Otherwise call `oracle-tab-binding' (default indent-relative: move to under
the start of the next word in the previous line, or `tab-to-tab-stop' if
there is no such word).

See Emacs documentation for `indent-relative'."
;;;------------------------
  (interactive "*")
  (let ((rec (recent-keys) )
	(last-but-one (- (length (recent-keys)) 2)))
    (save-match-data
      (if (and oracle-auto-indent-flag
	       (not (looking-at (concat ".*" oracle-protect-line-re)))
	       (not (eq 'tab (aref rec last-but-one )))
	       (save-excursion (re-search-backward "^\\|\\>")
			       (looking-at "^")))
	  (oracle-indent-line)
	(funcall oracle-tab-binding)))))

;;;------------------------
(defun oracle-case-indent-interactive (arg)
  "Indent and case according to Oracle mode.
Command invoked by typing an end-of-word character CHAR.

If cursor is immediately after a keyword, and `oracle-auto-case-flag' is non-nil,
adjust the case of the previous word by calling `oracle-case-last-word-if-key'.

If `oracle-auto-indent-flag' is non-nil:
   If the previous character was also CHAR, insert CHAR.
   If CHAR is a newline, indent the current line and insert CHAR with optional
        prefix argument ARG.
   Otherwise, insert CHAR with optional prefix argument ARG and then indent
        the current line."
;;;------------------------
  (interactive "*P")
  (let ((lastk last-command-char)
	(rec  (recent-keys))
	(last-but-one (- (length (recent-keys)) 2)))
    (if oracle-auto-case-flag (oracle-case-last-word-if-key lastk))
    (if oracle-auto-indent-flag
	(cond
	 ;; if command is repeated, just insert it
	 ((eq lastk (aref rec last-but-one)) (self-insert-command
					      (prefix-numeric-value arg)))
	 ;; indent first, then insert for \n and \r
	 ((eq lastk ?\n)   (oracle-indent-line) (funcall oracle-lfd-binding))
	 ((eq lastk ?\r)   (oracle-indent-line) (funcall oracle-ret-binding))

	 ;; for others, insert first, then indent
	 ((progn (self-insert-command (prefix-numeric-value arg))
		 (oracle-indent-line))))
      ;; no auto-indent
      (cond
       ((eq lastk ?\n)  (funcall oracle-lfd-binding))
       ((eq lastk ?\r)  (funcall oracle-ret-binding))
       ((self-insert-command (prefix-numeric-value arg)))))))

;;;------------------------
(defun oracle-case-last-word-if-key ( &optional nextchar )
  "If after a keyword, adjust the case of the previous word.
Use the case function `oracle-case-keyword-function'.
If NEXTCHAR is not a word constituent, treat the current position as
end-of-word.
Called by `oracle-case-indent-interactive' after an end-of-word character is typed."
;;;------------------------
  (if (not (oracle-in-protected-region-p))
      (if (and (> (point) (+ 1 (point-min)))
	       (oracle-after-keyword nextchar))
	  (funcall oracle-case-keyword-function -1))))


;;;------------------------
(defun oracle-indent-line ()
  "Indent the current line as SQL or PL/SQL as appropriate.
If the line starts with a closing paren, run `oracle-align-parens'.
If line starts with '/' do nothing.
Called by tab via `oracle-indent-or-tab' if not at end of line.

This is the indent-line function for `oracle-mode'."
;;;------------------------
  (interactive "*P")
  (if (>=  (count-lines (point) (point-min))  1 )
      (save-match-data
	(let ( (cmdlist) (cmd) (sql-cmd-align) (par) (protected)
	       (mat) (leftcomment))

	  ;; Decide if we are in an sql or plsql command
	  ;; or inside parens.

	  (save-excursion
	    (beginning-of-line)
	    (setq cmdlist (oracle-in-sql-command))
	    (setq cmd (car cmdlist))
	    (setq sql-cmd-align (cdr cmdlist))
	    ;; Comment starting --- or /* should left align
	    (setq leftcomment (looking-at (concat
					   "\\s-*\\("
					   oracle-leftcomment-start-re "\\)")))
	    ;; Skip sqlplus, "/" at the start of a line, or protected code
	    (setq protected (or (looking-at "^/")
				(looking-at (concat ".*" oracle-protect-line-re))
				( and (looking-at sqlplus-cmd-re)
				      (not (looking-at oracle-plsql-keyword-re))
				      (not cmd))))
	    ;; Align a ")" that is the first non-blank char in the line
	    ;; with the matching "("
	    (setq par (looking-at "\\s-*)")))
	  ;; Call the appropriate indentation function
	  (if (not  protected)
	      (if leftcomment
		  (let ((currcol (current-column))
			(currindent (current-indentation)))
		    (indent-line-to 0)
		    (move-to-column (- currcol currindent)))
		(if par
		    (oracle-align-parens)
		  (if cmd
		      (oracle-indent-as-sql (oracle-extract-cmd cmd) sql-cmd-align)
		    (oracle-indent-as-plsql)))))))))


;;;------------------------
(defun oracle-indent-as-sql (cmd sql-cmd-align)
  "Indent the line as part of the sql command CMD.
CMD is a SQL command keyword ending one column before the column SQL-CMD-ALIGN."
;;;------------------------
  (save-match-data
    (let  ((curr-indent) (align-col) (sub) (startpos (current-column))  )
      (save-excursion
        (back-to-indentation)
        (setq curr-indent (current-column))
        (setq sub (cdr-safe (assoc cmd oracle-sql-alist)))

        ;; If line starts with sub-part of sql cmd,
	;; align end of 1st word with end of cmd
        (if (and sub (looking-at sub ))
            (progn
              (if (equal (match-string 0) ")")
                  (forward-char)
                (forward-word 1))
              (setq align-col (+ (current-column) 1)))
          (setq align-col (current-column))))
      (let ((new-indent (+ curr-indent
			   (- sql-cmd-align align-col))))
        (if (< new-indent 0)
            (setq new-indent 0))
	(indent-line-to new-indent)
        (move-to-column (max 0 (+ startpos (- new-indent curr-indent))))))))
    


;;;------------------------
(defun oracle-indent-as-plsql ()
  "Indent the line with respect to the current PL/SQL command.
If not in a PL/SQL command, do not indent."
;;;------------------------
  (save-match-data
    (let ((level) (cmd) (sub) (startpos (current-column))
          (new-indent) (curr-indent (current-indentation)))
      (save-excursion
        (beginning-of-line)
        (if (oracle-search-back-ignore
             (concat oracle-plsql-cmd-end-re "\\|" oracle-plsql-cmd-re )
             (point-min))
            ;;
            ;; If we have a command start and have not passed its end
            ;; set indentation to that of the command. Check for "not cmd part"
            ;; to avoid "for each row", eg
            ;;
            (if (and (looking-at oracle-plsql-cmd-re)
                     (not (looking-at oracle-plsql-cmd-part-re)))
                (progn
		  ;; get rid of extra spaces
                  (setq cmd (oracle-extract-cmd (match-string 0)))
 
                  (skip-chars-forward " \t")
                  (setq level (+ (current-column) 3)))
              (setq level (current-indentation)))))
      ;;
      ;; Now check for "part" of cmd at start of line - dont indent that wrt cmd
      ;; Here we treat the case of being inside a command separately, so we can
      ;; have command "parts" that indent as part of one command but not as
      ;; part of another.
      ;;
      (if (null level)
          (setq new-indent 0)
        (save-excursion
          (back-to-indentation)
          (if cmd
              (progn
                (setq sub (cdr-safe (assoc cmd oracle-plsql-alist)))
                (if (and sub (looking-at sub))
                    (setq new-indent (- level oracle-plsql-basic-offset))
                  (setq new-indent level)))
            (if (and (looking-at oracle-plsql-cmd-part-re)
                     (>= level oracle-plsql-basic-offset) )
                ;; dont break if at start of line - PACKAGE ends with
                ;; "end" but we dont indent for it since there is usually only
                ;; one package per file.
                ( setq new-indent (- level oracle-plsql-basic-offset))
              (setq new-indent level)))))
      (indent-line-to new-indent)
      (move-to-column (max 0 (+ startpos (- new-indent curr-indent )))))))
  

;;;------------------------
(defun oracle-align-parens ()
  "Align `)' at start of line with matching '('."
;;;------------------------
  (interactive "*")
  (let ((doalign) (new-paren-pos) (old-paren-pos)
        (curr-column) (curr-indent) (new-indent))
    (save-match-data
      (save-excursion
        (beginning-of-line)
        (oracle-search-forward-ignore "\)" (save-excursion (end-of-line) (point)))
        (if (= (char-before (point)) ?\))
            (progn
              (setq doalign t)
              (setq old-paren-pos (1- (current-column) ))
              (save-excursion (backward-sexp)
                              (setq new-paren-pos (current-column)))))))
    (if doalign
        (progn
          (setq curr-column (current-column))
          (setq curr-indent (current-indentation))
          (setq new-indent (+ curr-indent (- new-paren-pos old-paren-pos)))
          (indent-line-to new-indent )
          (move-to-column (max 0 (+ curr-column (- new-indent curr-indent ))))))))



;;;;      ------------------------------------------------
;;;;           ** 4. INTERACTIVE COMMENT FUNCTIONS **
;;;;      ------------------------------------------------

;;;------------------------
(defun oracle-fill-comment-paragraph-prefix ()
  "Fill the current comment paragraph and indent it.
Point must be inside a comment.
Removes `oracle-fill-comment-postfix' (default '*/') from the ends of lines.
Resets match data."
;;;------------------------
  (interactive "*")
  (oracle-fill-comment-paragraph t))

;;;------------------------
(defun oracle-fill-comment-paragraph-postfix ()
  "Fill the current comment paragraph and indent it.
Point must be inside a comment.
Appends the string `oracle-fill-comment-prefix' (default '/*') to the start of
each line, and `oracle-fill-comment-postfix' (default '*/') to the end of
each line.
Resets match data."
;;;------------------------
  (interactive "*")
  (oracle-fill-comment-paragraph t t))


;;;------------------------
(defun oracle-fill-comment-paragraph (&optional justify postfix)
  "Fill the current comment paragraph.  Point must be inside a comment.

If JUSTIFY is non-nil, justify each line as well.
The possible values of JUSTIFY are  `full', `left', `right',
`center', or `none' (equivalent to nil).

If POSTFIX is non-nil, enclose the line in
`oracle-fill-comment-prefix' (default '/*') and
`oracle-fill-comment-postfix' (default '*/').

Otherwise, the line is started with `comment-start' (default '--'),
and any `oracle-fill-comment-postfix' characters are removed.
Resets match data."
;;;------------------------
  (interactive "*P")
  (let ((opos (point-marker))
        (begin nil)
        (end nil)
        (indent nil)
        (the-comment-start nil))

    (if postfix
	(setq the-comment-start oracle-fill-comment-prefix )
      (setq the-comment-start comment-start))
    ;; check if inside comment
    (if (not (oracle-in-comment-p))
        (error "Not inside comment"))

    ;;
    ;; find limits of paragraph
    ;;
    (message "Filling comment paragraph...")
    (save-excursion
      (beginning-of-line)
      ;; find end of paragraph
      (while  (looking-at (concat "[ \t]*\\("
                                  oracle-comment-start-re
                                  "\\).*$"))
        (forward-line 1))
      (backward-char)
      (setq end (point-marker))

      (goto-char opos)
      ;; find begin of paragraph
      (beginning-of-line)
      (while (and (looking-at (concat "[ \t]*\\("
                                      oracle-comment-start-re
                                      "\\).*$"))
                  ( > (point) (point-min)))
        (forward-line -1))

      (if (> (point) (point-min))
          (forward-line 1))

      ;; get indentation to calculate width for filling
      ;; first delete comment-start so line indents properly
      (if (looking-at (concat "[ \t]*" oracle-comment-start-re))
          (replace-match ""))
      (oracle-indent-line)

      (back-to-indentation)
      (setq indent (current-column))
      (setq begin (point-marker)) )
 
    ;; delete old postfix if necessary
    (save-excursion
      (goto-char begin)
 
      (while (re-search-forward (concat oracle-fill-comment-postfix-re
                                        "[ \t]*$")
                                end t)
        (replace-match "")))

    ;; delete leading whitespace and uncomment
    (save-excursion
      (goto-char begin)
      (beginning-of-line)
      (while (re-search-forward (concat "^[ \t]*\\("
                                        oracle-comment-start-re
                                        "\\|"
                                        oracle-fill-comment-prefix
                                        "\\)[ \t]*") end t)
        (replace-match "")))

    ;; calculate fill width
    (setq fill-column (- fill-column indent
                         (length the-comment-start)
                         (if postfix
                             (length oracle-fill-comment-postfix)
                           0)))
    ;; fill paragraph
    (fill-region begin end justify)
    (setq fill-column (+ fill-column
                         indent
                         (length the-comment-start)
                         (if postfix
                             (length oracle-fill-comment-postfix)
                           0)))

    ;; re-comment and re-indent region
    (save-excursion
      (goto-char begin)
      (indent-to indent)
      (insert the-comment-start)
      (while (re-search-forward "\n" end t)
        (replace-match (concat "\n" the-comment-start))
        (beginning-of-line)
        (indent-to indent)))

    ;; append postfix if wanted
    (if (and justify
             postfix
             oracle-fill-comment-postfix)
        (progn
          ;; append postfix
          (save-excursion
            (goto-char begin)
            (while (and (< (point) end)
                        (re-search-forward "$" end t))
              (replace-match
               (concat
                (make-string
                 (+ (- fill-column
                       (current-column)
                       (length oracle-fill-comment-postfix) )) ?\  )
                oracle-fill-comment-postfix ))
              (forward-line 1)))))
    (message "Filling comment paragraph...done")
    (goto-char opos))
  t)


;;;------------------------
(defun oracle-uncomment-region (beg end)
  "Delete `comment-prefix` from the start of each line in the region BEG, END.
Only works for comment-prefix (default '--'),
not for oracle-fill-comment-prefix/postfix (default /*..*/)."
;;;------------------------
  (interactive "*r")
  (comment-region beg end -1))


;;;;         ----------------------------------------------
;;;;         ** 5. BULK CASING AND INDENTATION FUNCTIONS **
;;;;         ----------------------------------------------

;;;------------------------
(defun oracle-base-case-region (from to)
  "Apply `oracle-base-case-function' to all non-quoted, non-key words in region.
Take all words in the region defined by FROM, TO that are not quoted,
commented or in the body of a sqlplus command, and process them  with
the command `oracle-base-case-function' (default `downcase-word' )."
;;;------------------------
  (interactive "*r")
  (save-excursion
    (goto-char from)
    ;;
    ;; loop: look for all word starts
    ;;
    (while (and (< (+ (point) 1) to))
      ;; do nothing if it is in a string or comment
      (if (and (not (oracle-in-protected-region-p ))
               (looking-at "\\<"))
          (funcall oracle-base-case-function 1)
        (forward-char 1)))))


;;;------------------------
(defun oracle-adjust-case-region (from to)
  "Adjusts the case of all words in the region defined by FROM, TO.
Resets match data."
;;;------------------------
  (interactive "*r")
  (save-excursion
    (goto-char to)
    ;;
    ;; loop: look for all identifiers and keywords
    ;;
    (while (and (> (point) from)
                (re-search-backward oracle-keyword-re from t))
      (progn
        (let (word (match-string 0))
          (or
           ;; do nothing if in a string or comment or sqlplus body
           (oracle-in-protected-region-p)
           (progn
             (funcall oracle-case-keyword-function 1)
             (forward-word -1))))))))

;;;------------------------
(defun oracle-indent-and-case-region (beg end)
  "Indent region  defined by BEG,END and adjust case of keywords only."
;;;------------------------
  (interactive "*r")
  (oracle-adjust-case-region beg end)
  (indent-region beg end nil))

;;;------------------------
(defun oracle-reformat-region (beg end)
  "Indent region.  Adjust case of keywords not quoted or commented.
Indent taking code before the region defined by BEG,END into account if
necessary.
Use `oracle-local-reformat-region` to treat the region in isolation."
;;;------------------------
  (interactive "*r")
  (message "Reformatting...")
  (oracle-base-case-region beg end)
  (oracle-adjust-case-region beg end)
  (indent-region beg end nil )
  (message "Reformatting...done"))

;;;------------------------
(defun oracle-local-reformat-region (beg end)
  "Indent region and adjust case of keywords.  Ignore rest of file.
Indent the region defined by defined by BEG, END as if the selected region
were the entire file, ignoring code before the region."
;;;------------------------
  (interactive "*r")
  (message "Reformatting...")
  (let (start)
    (if (> beg 1)
        ( setq start (- beg 1) )
      ( setq start beg ))
    (narrow-to-region start end))
  (oracle-base-case-region (point-min) (point-max))
  (oracle-adjust-case-region (point-min) (point-max))
  (indent-region (point-min) (point-max) nil )
  (widen)
  (message "Reformatting...done"))

;;;------------------------
(defun oracle-local-indent-and-case-region (beg end)
  "Indent region defined by BEG, END and adjust case of keywords only."
;;;------------------------
  (interactive "*r")
  (let (start)
    (if (> beg 1)
        ( setq start (- beg 1) )
      ( setq start beg ))
    (narrow-to-region start end))
  (oracle-adjust-case-region beg end)
  (indent-region beg end nil)
  (widen))

;;;------------------------
(defun oracle-local-indent-region (beg end)
  "Indent region defined by BEG, END ignoring code before region.
Indent as if the selected region were the entire file,
ignoring code before the region."
;;;------------------------
  (interactive "*r")
  (message "Reformatting...")
  (let (start)
    (if (> beg 1)
        ( setq start (- beg 1) )
      ( setq start beg ))
    (narrow-to-region start end))
  (indent-region (point-min) (point-max) nil )
  (widen)
  (message "Reformatting...done"))


;;;------------------------
(defun oracle-reformat-buffer ()
  "Indent buffer.  Adjust case of keywords not quoted or commented."
;;;------------------------
  (interactive "*")
  (message "Reformatting buffer...")
  (oracle-base-case-region (point-min) (point-max))
  (oracle-adjust-case-region (point-min) (point-max))
  (indent-region (point-min) (point-max) nil)
  (message "Reformatting buffer...done"))



;;;;      -----------------------------------------------------------
;;;;      ** 6. FUNCTIONS FOR USE ON SQLPLUS DESCRIBE-TABLE OUTPUT **
;;;;      -----------------------------------------------------------

;;;------------------------
(defun oracle-where-list(beg end)
  "Generate a join clause from the output of a sqlplus `DESCRIBE TABLE' command.
The region (BEG, END) is expected to consist of a string of the form
   COL1   TYPE1
   COL2   TYPE2
   COL3   TYPE3
\(part of the output from a sqlplus `describe table' command)
is inserted into the buffer and selected, this command replaces
the above text with:
          tabA.col1 = tabB.col1
      AND tabA.col2 = tabB.col2
      AND tabA.col3 = tabB.col3
where tabA and tabB are table aliases read from the minibuffer."
;;;------------------------
  (interactive "*r")
  (save-match-data
    (let ((left-table)
          (right-table)
          (wordlist ())
          (indent-column nil)
          (curr-word))
      (setq left-table (read-from-minibuffer "left table alias: "))
      (setq right-table (read-from-minibuffer "right table alias: "))
      (setq wordlist (oracle-first-words beg end))
      (if wordlist
          (progn
	    (setq curr-word (downcase (car wordlist)))
            (goto-char beg)
            (delete-region beg end)
	    (forward-word -1)
	    (if (looking-at "where")
		(forward-word 1)
	      (goto-char beg)
	      (insert "   "))
	    (setq indent-column (- (current-column) 3))
	    (insert (concat " " left-table "." curr-word " = "
			    right-table "." curr-word "\n"))
	    (setq wordlist (cdr wordlist))
	    (while wordlist
	      (setq curr-word (downcase (car wordlist)))
	      (insert (make-string indent-column  ?\ ) "AND "
		      (concat left-table "." curr-word " = "
			      right-table "." curr-word "\n"))
	      (setq wordlist (cdr wordlist))))))))


;;;------------------------
(defun oracle-variable-list (beg end)
  "Generate a pl/sql declaration list.
The region (BEG, END) is expected to consist of a string of the form
   COL1   TYPE1
   COL2   TYPE2
   COL3   TYPE3
\(part of the output from a sqlplus `describe table' command)
is inserted into the buffer and selected, this command replaces
the above text with:
     X_col1  .col1%type,
     X_col2  .col2%type,
     X_col3  .col3%type, ...
where X_ is a prefix read from the minibuffer.
Intended for generating PL/SQL variable declarations and
procedure argument lists."
;;;------------------------
  (interactive "*r")
  (let ((wordlist ())
        (curr-word)
        (indent-string)
        (prefix))
    (setq wordlist (oracle-first-words beg end))
    (setq prefix (read-from-minibuffer "prefix for variable name: "))
    (goto-char beg)
    (setq indent-string (make-string  (current-column) ?\ ))
    (delete-region beg end)
    (while wordlist
      (setq curr-word (downcase (car wordlist)))
      (insert prefix curr-word )
      (move-to-column  (+ (length indent-string) 20) t)
      (insert  "." curr-word "%type,\n" indent-string )
      (setq wordlist (cdr wordlist)))))


;;;------------------------
(defun oracle-comma-sep-line (beg end)
  "Generate a comma-separated column list, all in one line.
The region (BEG, END) is expected to consist of a string of the form
   COL1   TYPE1
   COL2   TYPE2
   COL3   TYPE3
\(part of the output from a sqlplus `describe table' command)
is inserted into the buffer and selected, this command replaces
the above text with:
     col1, col2, col3, ...
Intended for generating SELECT and INSERT clauses."
;;;------------------------
  (interactive "*r")
  (let ((wordlist ())
        (curr-word))
    (setq wordlist (oracle-first-words beg end))
    (goto-char beg)
    (delete-region beg end)
    (while wordlist
      (setq curr-word (downcase (car wordlist)))
      (insert curr-word ", " )
      (setq wordlist (cdr wordlist)))))

  
;;;------------------------
(defun oracle-comma-sep-list (beg end)
  "Generate a comma-separated column list, 1 per line.
The region (BEG, END) is expected to consist of a string of the form
   COL1   TYPE1
   COL2   TYPE2
   COL3   TYPE3
\(part of the output from a sqlplus `describe table' command)
is inserted into the buffer and selected, this command replaces
the above text with:
     col1,
     col2,
     col3, ...
Intended for generating SELECT and INSERT clauses."
;;;------------------------
  (interactive "*r")
  (let ((wordlist ())
        (curr-word)
        (indent-string))
    (setq wordlist (oracle-first-words beg end))
    (goto-char beg)
    (setq indent-string (make-string  (current-column) ?\ ))
    (delete-region beg end )
    (while wordlist
      (setq curr-word (downcase (car wordlist)))
      (insert curr-word ", \n" indent-string)
      (setq wordlist (cdr wordlist)))))


;;;------------------------
(defun oracle-comma-sep-triple (beg end)
  "Generate a comma-separated column list, 3 per line.
The region (BEG, END) is expected to consist of a string of the form
   COL1   TYPE1
   COL2   TYPE2
   COL3   TYPE3
   ......
\(part of the output from a sqlplus `describe table' command).
This command replaces the above text with:
     col1,         col2,          col3,
     col4,         col5,          col6,
     col7,         col8,  ...
Intended for generating long SELECT and INSERT clauses."
;;;------------------------
  (interactive "*r")
  (let ((wordlist ())
        (curr-word)
        (counter 1)
        (indent-string))
    (setq wordlist (oracle-first-words beg end))
    (goto-char beg)
    (setq indent-string (make-string  (current-column) ?\ ))
    (delete-region beg end )
    (while wordlist
      (setq curr-word (downcase (car wordlist)))
      (if (= 0 (mod counter 3))
          (insert (format "%-20s\n%s" (concat curr-word ",")  indent-string))
        (insert (format "%-20s" (concat curr-word ",")) ))
      (setq wordlist (cdr wordlist))
      (setq counter (+ counter 1)))))
     
;;;------------------------
(defun oracle-align-region-to-point (beg end)
  "Aligns the region defined by BEG, END so all lines start at its start column."
;;;------------------------
  (interactive "*r")
  (goto-char beg)
  (let ((lines 0)
        (newindent (current-column)))
    (while (< (point) end)
      (setq lines (+ lines 1))
      (forward-line))
    (goto-char beg)
    (let ((ln 1))
      (forward-line)
      (while (< ln lines)
        (setq ln (+ ln 1))
        (indent-line-to newindent)
        (forward-line)))))


;;;------------------------
(defun oracle-first-words (beg end)
  "Return a list of the first words of each line in the region.
Region is defined by BEG, END.
For use with the output of a DESCRIBE TABLE command."
;;;------------------------
  (save-match-data
    (let ((wordlist)
          (newword))
      (goto-char beg)
      (setq wordlist '())
      (while (< (point) end)
        (re-search-forward "\\<\\([^ \t\n]+\\)\\>" end t)
        (setq newword (match-string 1))
        (setq wordlist (append  wordlist (list newword)))
        (forward-line))
      wordlist )))

;;;;        --------------------------------------------
;;;;       ** 7. MISCELLANEOUS INTERACTIVE FUNCTIONS **
;;;;        --------------------------------------------

;;;------------------------
(defun oracle-test-expr ()
  "A debugging tool.
Check which sql regexps match the following word or words
immediately after point."
;;;------------------------
  (interactive)
  (let ((msg)
        (wd))
    (message "Current word is: < %s >" (current-word))
    (if (looking-at oracle-sql-keyword-re)
        (setq msg (concat msg "~ oracle-sql-keyword-re: " (match-string 0))))
    (if (looking-at oracle-comment-start-re)
        (setq msg (concat msg "~ oracle-comment-start-re: " (match-string 0))))
    (if (looking-at oracle-sql-cmd-re)
        (setq msg (concat msg "~ oracle-sql-cmd-re: " (match-string 0))))
    (if (looking-at oracle-command-end-re)
        (setq msg (concat msg "~ oracle-command-end-re: " (match-string 0))))
    (if (looking-at oracle-plsql-cmd-re)
        (setq msg (concat msg "~ oracle-plsql-cmd-re: " (match-string 0))))
    (if (looking-at oracle-plsql-cmd-part-re)
        (setq msg (concat msg "~ oracle-plsql-cmd-part-re: " (match-string 0))))
    (if (looking-at oracle-plsql-cmd-end-re)
        (setq msg (concat msg "~ oracle-plsql-cmd-end-re: " (match-string 0))))
    (if (looking-at oracle-plsql-keyword-re)
        (setq msg (concat msg "~ oracle-plsql-keyword-re: " (match-string 0))))
    (if (looking-at sqlplus-keyword-re)
        (setq msg (concat msg "~ sqlplus-keyword-re: " (match-string 0))))

    (if (oracle-in-string-p)
        (setq msg (concat msg "~ In-string ")))
    (if (oracle-in-blank-line-p)
        (setq msg (concat msg "~ In-blank-line ")))
    (if (oracle-in-comment-p) (setq msg (concat msg "~ In-comment ")))
    (if (oracle-in-sqlplus-body-p) (setq msg (concat msg "~ In-sqlplus-body ")))
    (if (oracle-in-sqlplus-p) (setq msg (concat msg "~ In-sqlplus ")))
    (if (oracle-in-string-comment-or-sqlplus-p)
        (setq msg (concat msg "~ In-str-or-comment ")))
    (if (oracle-in-protected-region-p)
        (setq msg (concat msg "~ In-protected-region ")))
    (let ((cmdlist (oracle-in-sql-command)))
      (message "cmdlist is %s" cmdlist )
      (if cmdlist
	  (setq msg (concat msg "~ In-sql-command " (car cmdlist) " indent to "
			    (number-to-string (cdr cmdlist) )))))
    (if (oracle-after-keyword)
        (setq msg (concat msg "~ after-keyword: ")))
    (message msg)
    (let (( pp (parse-partial-sexp (save-excursion  (beginning-of-line) (point)) (point))))
      (message  "sexp: 0=%s 1=%s 2=%s 3=%s 4=%s 5=%s 6=%s 7=%s 8=%s 9=%s 10=%s #" (nth 0 pp) (nth 1 pp)   (nth 2 pp)  (nth 3 pp)  (nth 4 pp)  (nth 5 pp)  (nth 6 pp)  (nth 7 pp)  (nth 8 pp)  (nth 9 pp)  (nth 10 pp) ))
    ))

;;;------------------------
(defun oracle-backtab ()
  "Move point backwards to previous indentation level."
;;;------------------------
  (interactive "*")
  (untabify (point-min) (point))
  (let ((start-indent)
        (backup (current-column)))
    (setq start-indent (- (current-column) 1))
    (save-excursion
      (while (and (>= backup start-indent)
                  (> (point) 1))
        (forward-line -1)
        (if (not (oracle-in-blank-line-p))
            (setq backup (current-indentation)))))
    (indent-line-to backup)))

;;;------------------------
(defun oracle-generate-group-by ()
  "(Re-)generate the GROUP BY clause of an sql select statement.
Not perfect, but helpful if the select list is long.
Fails to delete the column alias if it is after `)'."
;;;------------------------
  (interactive "*")
  (setq case-fold-search t)
  (let ((command (oracle-in-sql-command)) (start (point)) (end) (grpstart) (grpend) )
    (if (and (equal (car command) "SELECT")
	     (save-excursion (beginning-of-line)
			     (looking-at " *group +by")))
	(progn
	  (save-excursion
	    (oracle-search-back-ignore "SELECT")
	    (forward-word 1)
	    (setq start (point))
	    (oracle-search-forward-ignore "\\<from " (point-max))
	    (forward-word -1)
	    (setq end (point)))
	  (setq grpstart (make-marker))
	  (set-marker grpstart (point))
	  (insert (buffer-substring start end))
	  (setq grpend (make-marker))
	  (set-marker grpend (point))

	  (goto-char grpstart)
	  ;; First get rid of the grouping functions
	  (while (oracle-search-forward-ignore oracle-group-fcn-re grpend)
	    (replace-match "" nil nil )
	    (kill-sexp)
	    ;; remove the comma and any alias from the grouping function
	    (if (looking-at "[ \t]*\\(\\w\\|\\d\\)*,[ \t]*\n*")
		(replace-match "" nil nil ))
	    (if (> (point) grpend )
		(progn
		  (skip-chars-backward ",(\\s )*")
		  (delete-region (point) grpend))))
	     
	  ;; Then get rid of the column aliases
	  (goto-char grpstart)
	  (while (re-search-forward "[^ \t\n,]+\\(\\s +[^ ()\t\n,]+\\s *\\)," grpend t)
	    (let ((pp (parse-partial-sexp grpstart (1- (point)))))
	      (if  (and (= (nth 0 pp) 0 )
			(null (nth 4 pp))
			(null (nth 3 pp)))
		  (replace-match "" nil nil nil 1))))

	  ;; Remove a final column alias if there is one
	     
	  (while (re-search-forward  "[^ \t\n,]+\\(\\s +[^ ()\t\n,]+\\s *\\)" grpend t)
	    (let ((pp (parse-partial-sexp grpstart (1- (point)))))
	      (if  (and (= (nth 0 pp) 0 )
			(null (nth 4 pp))
			(null (nth 3 pp)))
		  (replace-match "" nil nil nil 1))))
	  )
      (message "not in group by clause of select statement"))))
				   

;;;;         ------------------------------------------
;;;;         ** 8. NON-INTERACTIVE UTILITY FUNCTIONS **
;;;;         ------------------------------------------

;;;------------------------
(defun oracle-extract-cmd (cmd)
  "Return CMD in lower case with whitespace compressed.
Initial tabs or spaces are stripped, and multiple internal
tabs or spaces replaced by single spaces."
;;;------------------------
  ;; Used to match up "create  or  replace", for instance, with the key
  ;; "create or replace" in oracle-plsql-alist.
  ;; 
  (save-match-data
    (let ((cmd-name))
      (setq cmd-name(downcase cmd))
      ;;
      ;; get rid of initial blanks and
      ;; replace other groups of blanks with one space
      ;;
      (if (string-match "^\\s-+" cmd-name)
          (setq cmd-name (replace-match "" 1 nil cmd-name)))
      (while (string-match "\\s-\\s-+" cmd-name)
        (setq cmd-name (replace-match " " 1 nil cmd-name)))
      cmd-name)))


;;;------------------------
(defun test-back ( )
  "Search back for regexp re, ignoring strings, comments, sqlplus commands and
anything inside paired parentheses.
If successful, return string matched, else return nil.
Resets match data."
;;;------------------------
  (interactive "*")
  (let (( re (read-from-minibuffer "enter re: ")) (bound (point-min)))
    ;;
    ;; return nil if in string or comment
    ;;
    (if (or (oracle-in-string-p) (oracle-in-comment-p))
	nil
      
      (let ((found nil))
	(while (and (not found) (> (point) bound)
		    (re-search-backward (concat ")\\|\\(" re "\\)") bound 1))
	  ;;
	  ;; skip back over any paired parens
	  ;;
	  (if (and (equal (match-string 0) ")")
		   (not (oracle-in-string-comment-or-sqlplus-p)))
	      (progn
		(forward-char)		; so we are after the )
		(backward-sexp))	; back to matching (
	    ;;
	    ;; Otherwise, check for string or comment
	    ;;
          
	    (if (not (oracle-in-string-comment-or-sqlplus-p))
		(setq found t))))

	(if (and (> (point) bound)
		 found
		 (not (oracle-in-string-comment-or-sqlplus-p)))
	    (match-string 0)
	  nil))))
  )

;;;------------------------
(defun oracle-search-back-ignore (re &optional bound )
  "Search back for regexp RE not in string, comments, sqlplus or ().
Search back for regexp RE, ignoring strings, comments,
sqlplus commands and anything inside paired parentheses.
Optional second argument BOUND limits the search, otherwise the limit
is the start of the buffer.
If successful, move to start of matched string, and return
the string matched, else return nil.
Resets match data."
;;;------------------------
  (if (null bound) (setq bound (point-min)))
  ;;
  ;; return nil if in string or comment
  ;;
  (if (or (oracle-in-string-p) (oracle-in-comment-p))
      nil
      
    (let ((found nil))
      (while (and (not found) (> (point) bound)
                  (re-search-backward (concat ")\\|\\(" re "\\)") bound 1))
        ;;
        ;; skip back over any paired parens
        ;;
        (if (and (equal (match-string 0) ")")
		 (not (oracle-in-string-comment-or-sqlplus-p)))
	    (progn
              (forward-char)		; so we are after the )
              (backward-sexp))		; back to matching (
          ;;
          ;; Otherwise, check for string or comment
          ;;
          
	  (if (not (oracle-in-string-comment-or-sqlplus-p))
	      (setq found t))))
      (if (and (> (point) bound)
	       found
	       (not (oracle-in-string-comment-or-sqlplus-p)))
	  (match-string 0)
        nil))))
          
;;;------------------------
(defun test-forward (&optional bound )
  "Search forward for regexp re, ignoring strings, comments,
sqlplus commands and anything inside paired parentheses.
Optional second argument BOUND limits the search, otherwise the limit
is the end of the buffer.
If successful, return the string matched, else return nil.
Resets match data."
;;;------------------------
  (interactive "*")
  (let ((re (read-from-minibuffer "enter re: ")))
    (if (null bound) (setq bound (point-max)))
    ;;
    ;; return nil if in string or comment
    ;;
    (if (oracle-in-string-comment-or-sqlplus-p)
	nil
      (let ((found nil))
	(while (and (not found) (< (point) bound))
	  (re-search-forward (concat "(\\|" re) bound 1)
	  ;;
	  ;; skip forward over any paired parens
	  ;;
	  (if (and (equal (match-string 0) "(")
		   (not (oracle-in-string-comment-or-sqlplus-p)))
	      (progn (forward-char -1)
		     (forward-sexp))	; forward to matching )
	    ;;
	    ;; Otherwise, check for string or comment
	    ;;
	    (if (not (oracle-in-string-comment-or-sqlplus-p))
		(setq found t))))
	(if found
	    (match-string 0)
	  nil)))))
          
   
;;;------------------------
(defun oracle-search-forward-ignore (re &optional bound )
  "Search back for regexp RE not in string, comments, sqlplus or ().
Search forward for regexp RE, ignoring strings, comments,
sqlplus commands and anything inside paired parentheses.
Optional second argument BOUND limits the search, otherwise the limit
is the end of the buffer.
If successful, move to end of matched string and return the
string matched, else move to limit of search and return nil.
Resets match data."
;;;------------------------
  (if (null bound) (setq bound (point-max)))
  ;;
  ;; return nil if in string or comment
  ;;
  (if (oracle-in-string-comment-or-sqlplus-p)
      nil
    (let ((found nil))
      (while (and (not found) (< (point) bound)
		  (re-search-forward (concat "(\\|" re) bound 1 ))
        ;;
        ;; skip forward over any paired parens
        ;;
        (if (and (equal (match-string 0) "(")
		 (not (oracle-in-string-comment-or-sqlplus-p)))
	    (progn (forward-char -1)
		   (forward-sexp))	; forward to matching )
          ;;
          ;; Otherwise, check for string or comment
          ;;
          (if (not (oracle-in-string-comment-or-sqlplus-p))
              (setq found t))))
      (if found
          (match-string 0)
        nil))))
          

;;;;              ----------------------------
;;;;              ** 9. CONTEXT INFORMATION **
;;;;              ----------------------------

;;;------------------------
(defun oracle-after-keyword(&optional nextchar)
  "If cursor is immediately after a keyword, return t, otherwise return nil.
If NEXTCHAR is not a word-constituent, treat the current position as
end-of-word.
Return nil when after non-alpha keywords such as (,!,@.
Do NOT check to see if the keyword is in a string or comment."
;;;------------------------
  (if (and (> (point) (point-min))
	   (equal (char-syntax (char-before (point))) ?w ))
      (if (or (null nextchar) (equal (char-syntax nextchar) "?w"))
	  (string-match oracle-keyword-re (current-word))
	(save-excursion
	  (save-match-data
	    (let ((endcol (current-column)))
	      (re-search-backward "\\<\\|^" (point-min) )
	      (string-match oracle-keyword-re
			    (substring (current-word) 0 (- endcol (current-column)))
			    )))))
    nil))

;;;------------------------
(defun oracle-in-blank-line-p ()
  "Return t if cursor is in a line consisting only of whitespace."
;;;------------------------
  (save-excursion
    (beginning-of-line)
    (looking-at "\\s-*$")))

;;;------------------------
(defun oracle-in-string-p ()
  "Return t if point is inside a string.
The string must start and end on the current line."
;;;------------------------
  ;;(Taken from pascal-mode.el).
  (save-excursion
    (nth 3
         (parse-partial-sexp
          (save-excursion  (beginning-of-line) (point))
          (point)))))

;;;------------------------
(defun oracle-in-sqlplus-body-p()
  "Return t if in the body of a sqlplus command.
ie if the current line starts with a sqlplus command,
and point is not inside or immediately after the command."
;;;------------------------
  (save-match-data
    (save-excursion
      (re-search-backward "\\> \\|^" (point-min))
      (if (not (looking-at "^"))
          (progn
            (beginning-of-line)
            (looking-at sqlplus-cmd-re))))))

;;;------------------------
(defun oracle-in-sqlplus-p()
  "Return t if in a line starting with a sqlplus command."
;;;------------------------
  (save-match-data
    (save-excursion
      (beginning-of-line)
      (and (looking-at sqlplus-cmd-re)
	   (not (oracle-in-sql-command))))))


;;;------------------------
(defun oracle-in-comment-p ()
  "Return t if inside a comment.
A comment is defined as everything from the end of
`oracle-comment-start-re' to the end of the line,
where the match string is not quoted."
;;;------------------------

  (let ((startpt (point)) (linestart (save-excursion (beginning-of-line) (point))))
    (save-match-data
      (save-excursion
	(re-search-backward oracle-comment-start-re linestart 1)
        (and (looking-at oracle-comment-start-re)
             ;; we are not in the middle of the comment-start expression
             (search-forward (match-string 0) startpt t)
             (>= startpt (point))
             ;; the comment-start is not quoted
	     (not (oracle-in-string-p)))))))


;;;------------------------
(defun oracle-in-sql-command()
  "Return the command and its indent level if inside a sql command.
Search back (ignoring quotes and comments) for the last sql command
start or command end.

If the search finds the end of an sql command, return nil.

If it is a command that is found, return (CMD . COL), where
CMD is the sql command string found, and  COL is the column after the
last one of the string CMD.
It is the column to which the body of the command is indented."
;;;------------------------
  (save-match-data
    (save-excursion
      (oracle-search-back-ignore (concat oracle-sql-cmd-re "\\|" oracle-command-end-re )
				 (point-min) )
      (if (and (looking-at oracle-sql-cmd-re)
	       (not (oracle-in-sqlplus-body-p)))
	  (let ((cmd (match-string 0)))
	    (re-search-forward ".\\>\\|(" (point-max) 1)
	    (cons cmd (1+ (current-column))))
	nil))))


;;;------------------------
(defun oracle-in-string-comment-or-sqlplus-p()
  "Return t if inside a string, comment or sqlplus command."
;;;------------------------
  (or (oracle-in-comment-p)
      (oracle-in-sqlplus-p)
      (oracle-in-string-p)))

;;;------------------------
(defun oracle-in-protected-region-p()
  "Return t if inside a string, comment or sqlplus body."
;;;------------------------
  (or (oracle-in-comment-p)
      (oracle-in-sqlplus-body-p)
      (oracle-in-string-p)))


;;;;              ---------------------------------------------------
;;;;              ** 10. ORACLE-MODE INTERACTING WITH SQLPLUS-MODE **
;;;;              ---------------------------------------------------

(defun oracle-append-query (point-min point-max)
  "Copies region to a generic query window and places it in oracle-mode"
  (interactive "r")
  (if (get-buffer oracle-append-buffer) nil
    (generate-new-buffer oracle-append-buffer)
    )
  (save-excursion
    (set-buffer oracle-append-buffer)
    (goto-char (point-max))
    (insert "\n\n")
    )	   
  (append-to-buffer oracle-append-buffer point-min point-max)
  (set-buffer oracle-append-buffer)
  (oracle-mode)
  )

(defun oracle-send-buffer (prefix-arg)
  "Execute all SQL*Plus commands defined in current buffer.
Output is displayed in the *sqlplus* buffer."
  (interactive "P")
  (oracle-send-region (point-min) (point-max) prefix-arg)
  )

(defun oracle-send-region (start end prefix-arg)
  "Execute all SQL*Plus commands defined between point and mark.
Output is displayed in the *sqlplus* buffer.
If buffer name ends in .lin, then take everything after the last line
with `TEXT,#' or `CVAL,#' on it as the region."
  (interactive "r\nP")
  (let (process this-buffer temp-file-name start-query
		temp-buffer linsp)
    (setq this-buffer (current-buffer))
    (setq process (sqlplus-choose-process))
    (setq sqlplus-last-process-buffer (process-buffer process))
    ;; Create oracle-file-directory directory.
    (unless (file-exists-p oracle-file-directory)
      (make-directory oracle-file-directory t))
    (setq temp-file-name (expand-file-name (make-temp-name (concat oracle-file-directory "/sqlplus.buf"))))
    (setq linsp (not (null (string-match sqlplus-lins-filename-ext (buffer-name)))))
    
    ;; See if there are any SQL*Plus or lins variables that need to be
    ;; substituted.  If there are, and no prefix has been passed in, write
    ;; everything out to a new buffer because it must be manipulated.
    (if (and (null prefix-arg)
	     (save-excursion
	       (goto-char start)
	       (or linsp
		   (re-search-forward
		    "\\binto\\s-+:\\|\\s-:\\w+\\|&.*&.*&" end t))))
	(progn
	  (setq temp-buffer (get-buffer-create oracle-temp-buffer))
	  (setq start-query 
		(save-excursion
		  (goto-char end)
		  (if (re-search-backward "\\(TEXT\\|CVAL\\),[0-9]+$"
					  (point-min) t)
		      (progn
			(forward-line 1)
			(beginning-of-line)
			(point))
		    start)))
	  (set-buffer temp-buffer)
	  (set-syntax-table oracle-mode-syntax-table) ; important for regular
					; expressions
	  (erase-buffer)
	  (insert-buffer-substring this-buffer start-query end)
	  (skip-chars-backward "\n\t ")	; trim trailing whitespace

	  ;; Make sure the last character is a '/' so the SQL statement
	  ;; executes.
	  ;;(forward-char 1)
	  (if (not (looking-at ";\\|/"))
	      (insert "\n/\n"))

	  ;; Look for variables over 30 characters and truncate
	  (goto-char (point-min))
	  (while (re-search-forward "&\\w+" (point-max) t)
	    (if (not (oracle-mode-in-comment))
		(let ( (wbeg (match-beginning 0)) (wend (match-end 0)) )
		  (if (> (- wend wbeg) 30)
		      (progn
			(delete-region (+ wbeg 1) (- wend 30))
			(setq oracle-mode-rebuild-comments t))))))
	  
	  ;; Substitute all variables with their values
	  (goto-char (point-min))
	  (while (re-search-forward "&\\(.+\\)\\." (point-max) t)
	    (if (not (oracle-mode-in-comment))
		(let* ((sql-var-name
			(buffer-substring (match-beginning 1) (match-end 1)))
		       (sql-var-value (read-from-minibuffer
				       (format "Replace '%s' with: "
					       sql-var-name)
				       nil nil nil nil))
		       (next-search (match-end 1)))
		  (goto-char (point-min))
		  (while (search-forward (concat "&" sql-var-name ".")
					 (point-max) t)
		    (if (not (oracle-mode-in-comment))
			(replace-match sql-var-value t t)))
		  (goto-char next-search))))

	  ;; Reset the start and end since we're in a temporary buffer now.
	  (setq start (point-min)
		end (point-max))))
    
    (write-region start end temp-file-name nil 0)
    (switch-to-buffer-other-window (process-buffer process))
    (goto-char (point-max))
    (recenter 0)
    (insert (format "\nOutput from buffer '%s':\n" 
		    (buffer-name this-buffer)))
    (set-marker (process-mark process) (point))
    (sit-for 0)				; update display
    (process-send-string process (concat "@" temp-file-name "\n"))
    (if temp-buffer (kill-buffer temp-buffer))
    (goto-char (point-max))		; allow entry of variables
    (switch-to-buffer-other-window this-buffer)))

(defun oracle-mode-in-rem-comment ()
  "Returns t if point is on a REM (comment) line."
  (save-excursion
    (beginning-of-line)
    (let ((case-fold-search t))
      (looking-at oracle-mode-rem-comment-re))))

(defun oracle-mode-build-comments ()
  "Create a list of start and end comment positions in the current buffer.
This only does the rebuild if oracle-mode-rebuild-comments is t."
  (if oracle-mode-rebuild-comments
      (save-excursion
	(let ((oracle-mode-rem-comments nil)
	      (oracle-mode-slash-comments nil))
	  (goto-char (point-min))
	  ;; First get the positions of all REM statements
	  (let ((case-fold-search t))
	    (while (re-search-forward oracle-mode-rem-comment-re (point-max) t)
	      (setq oracle-mode-rem-comments
		    (append oracle-mode-rem-comments
			    (list (list (progn
					  (beginning-of-line)
					  (point))
					(progn
					  (end-of-line)
					  (point))))))))
	  ;; Now start over and look for the /* ... */ pairs
	  (goto-char (point-min))
	  (while (search-forward "/*" (point-max) 1)
	    (if (oracle-mode-in-rem-comment)
		;; We're in a REM comment.  Go to the next line
		(progn
		  (forward-line 1)
		  (beginning-of-line))
	      ;; Found a legit /*; now search for the corresponding */
	      (let ((comment-start (- (point) 2))
		    (found nil))
		(while (and
			(not found)
			(search-forward "*/" (point-max) 1))
		  (if (not (oracle-mode-in-rem-comment))
		      (progn
			(setq oracle-mode-slash-comments
			      (append oracle-mode-slash-comments
				      (list (list comment-start (point)))))
			(setq found t)))))))
	  (setq oracle-mode-comments
		(append oracle-mode-rem-comments oracle-mode-slash-comments))
	  (make-local-variable 'oracle-mode-comments)
	  (setq oracle-mode-rebuild-comments nil)))
    t))

(defun oracle-mode-in-comment ()
  "Returns t if the point is within a REM or /* ... */ style comment."
  (let ((comments oracle-mode-comments)
	(found nil))
    (while (and
	    (not (null comments))
	    (not found))
      (let ((start (car (car comments)))
	    (end (car (cdr (car comments)))))
	(if (and (>= (point) start) (<= (point) end))
	    (setq found t))
	(setq comments (cdr comments))))
    found))


(defun oracle-format-temp-buffer (temporary-buffer begin-text end-text)
  "A function used to format temporary buffers for use with oracle-mode.
Formats the buffer with the ability to insert items at the beginning
and end of the buffer."
  (copy-to-buffer temporary-buffer (point-min) (point-max))
  (save-excursion
    (set-buffer temporary-buffer)
    (oracle-mode)
    (goto-char (point-min))
    (insert begin-text)
    (goto-char (point-max))
    (insert end-text)
    (oracle-send-buffer nil))
  (kill-buffer temporary-buffer))

(defun oracle-explain ()
  "Executes an explain statement and shows the explain plan for
a sql file currently in oracle-mode."
  (interactive)
  (oracle-format-temp-buffer
   oracle-explain-buffer
   "set echo off\nexplain plan for\n"
   "\nselect * from table(dbms_xplan.display);"))

(defun oracle-autotrace ()
  "Sets autotrace on for a session and shows the autotrace output.
Turns autotrace off for the session once it's complete."
  (interactive)
  (oracle-format-temp-buffer
   oracle-explain-buffer
   "set autotrace on explain stat\n"
   "\nset autotrace off"))

(defun oracle-autotrace-explain ()
  "Sets autotrace with explain only on for a session and shows the autotrace output.
Turns autotrace off for the session once it's complete."
  (interactive)
  (oracle-format-temp-buffer
   oracle-explain-buffer
   "set autotrace trace explain\n"
   "\nset autotrace off"))

(defun oracle-plsql-navigator ()
  "Use `occur' to create a stored unit map in a side window"
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward oracle-plsql-unit-re nil t)
	(progn (split-window-horizontally (/ (frame-width) oracle-plsql-nav-ratio))
	       (other-window 1)
	       (occur oracle-plsql-unit-re oracle-plsql-nav-nlines)
	       (other-window 1))
      (message "No stored program units found"))))


;;;;                  -------------------------------------------------
;;;;                  ** 11. SQLPLUS-MODE AND ACCOMPANYING FUNCTIONS **
;;;;                  -------------------------------------------------

(defun sqlplus-mode ()
  "This mode is normally invoked by 'M-x sqlplus' (not 'M-x sqlplus-mode').
You will be prompted to enter a username/password combination
to access the Oracle database.

There are two ways of editing and re-executing prior commands.
'\\[sqlplus-back-command]' and '\\[sqlplus-forward-command]' will 
move to the location in the buffer of the previous or next SQL 
statement, respectively (based on the command prompt).  The command
can then be edited normally and re-executed by pressing Return.

To insert a newline, you may press '\\[newline-and-indent]'.
'\\[sqlplus-next-command]' and '\\[sqlplus-previous-command]' are 
similar except the next or previous SQL statement is inserted at the 
end of the buffer.  Repeating these commands will clear the current 
statement and recall the next or previous statement from the stack.
For additional information on command execution use '\\[describe-key] RTN'.

'\\[sqlplus-show-output]' will move to the beginning of the last ouput
generated by SQL*plus.  This is useful for reviewing the results of 
the last statement.  '\\[sqlplus-end-of-buffer]' moves to the end of the buffer, 
but unlike '\\[end-of-buffer]' (end-of-buffer), it does not set the mark."

  (interactive)

  (kill-all-local-variables)

  (make-local-variable 'comment-start)
  (setq comment-start oracle-comment-prefix)

  ;; comment-end must be set because it may hold a wrong value if
  ;; this buffer had been in another mode before.
  (make-local-variable 'comment-end)
  (setq comment-end "")

  (make-local-variable 'comment-start-skip)
  ;; used by autofill, font-lock, etc
  (setq comment-start-skip
        "--+[ \t]*\\|\\/\\*[ \t]*\\|\\<rem[ \t]+\\|\\<prompt[ \t]+")

  (make-local-variable 'mark-even-if-inactive)
  ;; needed to avoid re-selecting for "desc table" functions
  (setq mark-even-if-inactive t)

  (set (make-local-variable 'comment-padding) 0)

  (make-local-variable 'parse-sexp-ignore-comments)
  ;; needed for paren balancing
  (setq parse-sexp-ignore-comments t)

  ;; the associated font-lock faces
  (make-local-variable 'font-lock-defaults)
  (setq oracle-font-lock-keywords
	(list
	 (list (concat sqlplus-cmd-re ".*$") 0 'font-lock-reference-face t)
	 ;;(list (concat oracle-comment-start-re ".*$") 0 'font-lock-comment-face t)
	 (cons oracle-plsql-keyword-re  'font-lock-keyword-face )
	 (cons oracle-sql-type-re  'font-lock-type-face )
	 (cons oracle-sql-keyword-re  'font-lock-function-name-face )
	 (cons oracle-sql-warning-word-re 'font-lock-warning-face)
	 (cons oracle-sql-reserved-word-re 'font-lock-keyword-face)
	 ;;(cons sqlplus-prompt 'font-lock-function-name-face)
	 (list oracle-sql-function-re 1 'font-lock-builtin-face )
	 ))


  (setq font-lock-defaults
	'(oracle-font-lock-keywords  nil t  nil nil ))

  (make-local-variable 'case-fold-search)

  ;; Oracle sql is case-insensitive
  (setq case-fold-search t)

  (make-local-variable 'fill-paragraph-function)
  (setq fill-paragraph-function 'oracle-fill-comment-paragraph)

  (setq major-mode 'sqlplus-mode)
  (setq mode-name "SQL*Plus")
  (setq mode-line-process '(": %s"))
 
  ;; create sqlplus-mode-syntax-table
  ;; unless it is already set, begin with oracle-mode-syntax-table
  (oracle-create-syntax-table)
  (if sqlplus-mode-syntax-table
      nil
    (setq sqlplus-mode-syntax-table oracle-mode-syntax-table)
     )
  (set-syntax-table sqlplus-mode-syntax-table)

  ;;; make any modifications to sqlplus-mode-syntax-table specific for sqlplus-mode  
  ;;(modify-syntax-entry ?\. "w" sqlplus-mode-syntax-table)

  ;; sqlplus-mode specifics (if needed) should begin here

  (setq local-abbrev-table oracle-mode-abbrev-table)
  (make-local-variable 'sqlplus-last-output-start)
  (setq sqlplus-last-output-start (make-marker))
  (make-local-variable 'sqlplus-prompt-re)
  (make-local-variable 'sqlplus-continue-pattern)
  (setq indent-tabs-mode nil)
  (setq left-margin 5)
  (abbrev-mode 1)
  (setq abbrev-all-caps 1)
  (setq sqlplus-tab-width 8)
  (setq sqlplus-tab-stop-list '(8 16 24 32 40 48 56 64 72 80 88 96 104))
  (use-local-map sqlplus-mode-map)
  (run-hooks 'sqlplus-mode-hook)
  )


(if sqlplus-mode-map
    nil
  (setq sqlplus-mode-map (make-sparse-keymap))
  (define-key sqlplus-mode-map "\C-m"     'sqlplus-execute-command)      
  (define-key sqlplus-mode-map "\t"       'indent-relative)                
  (define-key sqlplus-mode-map "\C-c\C-c" 'sqlplus-current-schema) 
  (define-key sqlplus-mode-map "\C-c\C-r" 'sqlplus-show-output)      
  (define-key sqlplus-mode-map "\C-c\C-p" 'sqlplus-previous-command) 
  (define-key sqlplus-mode-map "\C-c\C-n" 'sqlplus-next-command)     
  (define-key sqlplus-mode-map "\C-c\C-b" 'sqlplus-back-command)     
  (define-key sqlplus-mode-map "\C-c\C-f" 'sqlplus-forward-command)  
  (define-key sqlplus-mode-map "\C-c\C-k" 'sqlplus-kill-command)     
  (define-key sqlplus-mode-map "\C-c\C-x" 'sqlplus-reset-buffer)
  (define-key sqlplus-mode-map "\C-c\C-w" 'sqlplus-waits)        
  (define-key sqlplus-mode-map "\C-c\M-w" 'sqlplus-waits-px)        
  (define-key sqlplus-mode-map "\C-c\C-s" 'sqlplus-current-sql)
  (define-key sqlplus-mode-map "\C-c\C-o" 'sqlplus-object-ddl)
  (define-key sqlplus-mode-map "\C-c\C-i" 'sqlplus-index-ddl)
  (define-key sqlplus-mode-map "\C-c\C-t" 'sqlplus-tablespace-ddl)
  (define-key sqlplus-mode-map "\C-c\C-u" 'sqlplus-user-ddl)
  (define-key sqlplus-mode-map "\C-c\C-d" 'sqlplus-desc)
  (define-key sqlplus-mode-map "\C-c\M-d" 'sqlplus-desc-tab)
  (define-key sqlplus-mode-map "\C-c\C-l" 'sqlplus-longops)
  (define-key sqlplus-mode-map "\C-c\M-l" 'sqlplus-longops-px)
  (define-key sqlplus-mode-map "\C-c\C-v" 'sqlplus-sessions)
  )


;;-----------------------------

;;;###autoload
(defun sqlplus ()
  "Start up an interactive SQL*Plus session in a new buffer.
The buffer will be named after your Oracle logon, allowing you to easily
distinguish between several sessions.

If sqlplus-keep-history is non-nil, then the command history stored in
the .sqlhist file is inserted into the buffer, so those commands can be
recalled.

If sqlplus-do-commands-clear is non-nil, then all SQL*Plus commands will
be removed from the buffer, leaving only pure SQL statements.

If sqlplus-do-prompts-clear is non-nil, then all repititions of the
sqlplus-command-prompt on the same line will be replaced with a single
instance."

  (interactive)
  (let ((process (sqlplus-start)))
    (switch-to-buffer (process-buffer process))
    (if (and sqlplus-load-history
	     (file-readable-p (expand-file-name (concat oracle-file-directory "/" sqlplus-history-file))))
	(progn
	  (sit-for 1)
	  (while (accept-process-output) (sleep-for 1)) 
	  (sqlplus-load-session)
	  ;; 	  (insert-file-contents (expand-file-name (concat oracle-file-directory "/" sqlplus-history-file)) nil)
	  ;; 	  (goto-char (point-max))
	  (set-marker (process-mark process) (point))
	  (if sqlplus-do-commands-clear
	      (progn (sleep-for 1)
		     (sqlplus-clear-commands)))
	  (if sqlplus-do-prompts-clear
	      (sqlplus-clear-prompts))
	  (if sqlplus-do-clear-dangerous-sql
	      (sqlplus-clear-dangerous-sql)))
      (message "Session History Loaded"))))


(defun sqlplus-clear-prompts ()
  "Can be used to remove repititive iterations of the sqlplus-prompt
from the buffer."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward (concat "\\(" sqlplus-prompt " \\)\\{2,\\}") nil t)
      (replace-match (concat sqlplus-prompt " ") nil nil))
    (goto-char (point-max))))


(defun sqlplus-read-passwd (prompt &optional default)
  "Read a password from the user. Echos a . for each character typed.
End with RET, LFD, or ESC. DEL or C-h rubs out.  ^U kills line.
Optional DEFAULT is password to start with."
  (let ((pass (if default default ""))
	(c 0)
	(echo-keystrokes 0)
	(cursor-in-echo-area t))
    (while (and (/= c ?\r) (/= c ?\n) (/= c ?\e))
      (message "%s%s"
	       prompt
	       (make-string (length pass) ?.))
      (setq c (read-char))
      (if (= c ?\C-u)
	  (setq pass "")
	(if (and (/= c ?\b) (/= c ?\177))
	    (setq pass (concat pass (char-to-string c)))
	  (if (> (length pass) 0)
	      (setq pass (substring pass 0 -1))))))
    (message "")
    (substring pass 0 -1)))

(defun sqlplus-start ()
  "Start up an interactive SQL*Plus session in a new buffer."
  (let* ((sqlplus-connection-string (read-string "Enter SQL*plus username: "))
	 (service (if (string-match "@\\w+" sqlplus-connection-string)
		      ;; If there's a service specified, copy it off and remove it
		      (substring sqlplus-connection-string (match-beginning 0) (match-end 0))
		    ""))
	 (user (if (string-match "\\w+/" sqlplus-connection-string)
		   (substring sqlplus-connection-string (match-beginning 0) (1- (match-end 0)))
		 (if (string-match "/" sqlplus-connection-string)
		     "/"
		   ;; Must be no password
		   (if (string-match "\\w+@" sqlplus-connection-string)
		       (substring sqlplus-connection-string (match-beginning 0) (1- (match-end 0)))
		     ;; Only possibility left is that the only thing entered was a username
		     sqlplus-connection-string)
		   )))
	 (sqlplus-buffer (generate-new-buffer (concat "*sqlplus-" user service "*")))
	 (saved-buffer (current-buffer))
	 sqlplus-password
	 process)
    ;; Don't throw in password to SQL*Plus as an argument because it will show
    ;; up in a `ps'.
    (setq process			; Start new process
	  (save-excursion
	    (set-buffer sqlplus-buffer)
	    (insert sqlplus-startup-message)
	    (start-process "SQL*plus" sqlplus-buffer "sqlplus"
			   sqlplus-connection-string)))
    (set-buffer sqlplus-buffer)
    (goto-char (point-max))
    (set-marker (process-mark process) (point))
    (sqlplus-mode)
    ;; If the logon doesn't contain `/', then prompt for a password and send
    ;; it to the process.
    (if (not (string-match "/" sqlplus-connection-string))
	(progn
	  (setq sqlplus-password
		(sqlplus-read-passwd
		 (format "Enter SQL*plus password for %s: "
			 sqlplus-connection-string)))
	  (process-send-string process (concat sqlplus-password "\n"))))
    (if sqlplus-use-startup-commands
	(process-send-string process (concat sqlplus-startup-commands "\n")))
    (set-buffer saved-buffer)
    process				; return process
    )
  )

(defun sqlplus-execute-command ()
  "When executed at end of buffer, sends text entered since last 
output from SQL*Plus.  When executed while positioned within another
valid command in the buffer, copies command to end of buffer and 
re-executes it.  If point is within a multi-line statement at the end
of the buffer (such as after '\\[sqlplus-previous-command]'), the entire
statement will be cleared and re-entered one line at a time.

Multi-line statements are recognized by the continuation prompt displayed
by SQL*Plus.  This is controlled by the variable sqlplus-continue-pattern
which defaults to recognize either a right-justified number padded to four 
characters followed by a space or asterisk, or simply five spaces.  A line
ending with \";\" or \" /\" is also considered the end of a statement.
A new line inserted into a prior statement must be indented at least five
spaces to be included when the statement is re-executed. 

The output from a List command is also recognized as a valid SQL*Plus
statement; the 'List' command itself is stripped out (as are 'Get' and 'Run').

When a complex SQL statement is executed, it may take a long time before
the output is generated.  Emacs may appear to be hung since no keystrokes
are accepted until the first character of output arrives.  In this situation
'\\[keyboard-quit]' may be used to force emacs to stop waiting for output.
You may then switch to another buffer to perform other work while you wait
or press '\\[sqlplus-interrupt-subjob]' to cancel the current SQL command."
  (interactive)
  (let ((process (get-buffer-process (current-buffer))))
    (if (not process) 
	(error "Current buffer has no process.  Use 'M-x sqlplus' to start SQL*Plus process.")
      )

    (cond
					; last line of buffer and only one input line
     ((and (save-excursion (end-of-line) (eobp)) 
	   (<= (count-lines (process-mark process) (point)) 1))
      (end-of-line)
      (sqlplus-send-line process)
      )

					; within last multi-line command of buffer 
     ((not (save-excursion (re-search-forward sqlplus-prompt-re (point-max) t)))
      (let ((command-lines (sqlplus-get-command)))
	(sqlplus-kill-command t)        ; clear existing command lines
	(while command-lines            ; send command lines
	  (insert (car command-lines))
	  (sqlplus-send-line process)
	  (setq command-lines (cdr command-lines))
	  )
	)
      )
					; otherwise - prior command in buffer
     (t                                 
      (or (save-excursion
	    (beginning-of-line)
	    (looking-at (concat sqlplus-prompt-re "\\|" sqlplus-continue-pattern)))
	  (error "This is not a valid SQL*plus command."))
      (let ((command-lines (sqlplus-get-command))
	    (sql-line-number 1))
	(goto-char (point-max))
	(sqlplus-kill-command t)      ; clear pending command (if any)
	(while command-lines
	  (insert (car command-lines))
	  ;; Make sure there is a trailing ';' if this is the last line
	  (and (not (cdr command-lines)) ; no more lines remaining
	       (not (string-match "^\\(.*;$\\| */\\)$" (car command-lines)))
	       (insert ";"))
	  (sqlplus-send-line process)
	  (setq command-lines (cdr command-lines))
	  )
	)
      )
     )					;end cond
    )					;end let
  (setq sqlplus-stack-pointer 0)
  )					; end defun

(defun sqlplus-send-line (process) ; called from sqlplus-execute-command
  (insert ?\n)
  ;; Create oracle-file-directory directory.
  (unless (file-exists-p oracle-file-directory)
    (make-directory oracle-file-directory t))
  (let ((command (buffer-substring (process-mark process) (point)))
	(temp-file (expand-file-name (concat oracle-file-directory "/sqlplus.buf"))))
    (move-marker sqlplus-last-output-start (point))
					; trap EDIT command - must be the only word on the line
    (if (string-match "^ *edit\\s-*\\(\\w*\\)[ ;]*$" command) 
	(let (command-lines 
	      (edit-file-name (save-excursion (and 
					       (re-search-backward "edit\\s-+\\([^ \t\n;]+\\)" 
								   (process-mark process) t)
					       (buffer-substring (match-beginning 1) (match-end 1))
					       )))

	      )
	  (sit-for 0)
	  (set-marker (process-mark process) (point))
	  (process-send-string process "LIST\n")
	  (accept-process-output process) ; wait for process to respond
	  (sleep-for 1)
	  (forward-line -1)
	  (setq command-lines (sqlplus-get-command)) ; capture command
	  (delete-region sqlplus-last-output-start (point)) ; delete listed lines
	  (goto-char (point-max))
	  (switch-to-buffer-other-window (get-buffer-create (or edit-file-name oracle-edit-buffer)))
	  (if edit-file-name 
	      (setq buffer-offer-save t)
	    )
	  (delete-region (point-min) (point-max)) ; clear buffer
	  (while command-lines		;insert command lines
	    (insert (car command-lines) "\n")
	    (setq command-lines (cdr command-lines))
	    )
	  (insert "/\n")
	  (goto-char (point-min))
	  (oracle-mode)			;turn on oracle-mode
	  )
					;   else
					; execute command line
      (process-send-string process command)
      (goto-char (point-max))
      (set-marker (process-mark process) (point))
      (sit-for 0)			; force display update
      (accept-process-output)		; wait for process to respond
      )
					; trap QUIT command
    (if (string-match "^ *\\(exit\\|quit\\)[ ;]*$" command)
	(progn
	  (if sqlplus-keep-history
	      (let ((lines-to-keep (or sqlplus-lines-to-keep 1000)))
		(and (> (count-lines (point-min) (point-max)) lines-to-keep)
		     (y-or-n-p 
		      (format "Current session is longer than %d lines.  Ok to truncate? " lines-to-keep))
		     (sqlplus-drop-old-lines lines-to-keep)
		     )
		;; Create oracle-file-directory directory.
		(unless (file-exists-p oracle-file-directory)
		  (make-directory oracle-file-directory t))
		(sqlplus-save-session (concat oracle-file-directory "/" sqlplus-history-file))
		)
	    )
	  (while (get-buffer-process (current-buffer)) 
	    (sit-for 1))		; wait for process to die
	  (kill-buffer (current-buffer))
	  (and (file-exists-p temp-file) ; if sqlplus.buf exists, delete it
	       (delete-file temp-file))
	  )				;end progn
      )					;end if
    )					;end let
  )


(defun sqlplus-kill-command (command-only-flag)
  "Delete the current SQL command or output generated by last SQL command.
When used at the end of the buffer, serves as an undo command.

If point is within a valid SQL statement, delete region from SQL> prompt 
before point to end of buffer, otherwise delete all text between the end 
of the prior SQL statement and the end of the buffer."
  (interactive "P")
  (let ((process (get-buffer-process (current-buffer))))
    (if (or command-only-flag
	    (save-excursion
	      (beginning-of-line)
	      (looking-at (concat sqlplus-prompt-re ".+\\|" sqlplus-continue-pattern))
	      )
	    )
					;then - delete command and everything beyond
	(progn
	  (delete-region (progn 
			   (re-search-backward sqlplus-prompt-re (point-min) t) 
			   (point))
			 (point-max))
	  (process-send-string process "\n") ; generate new SQL> prompt
	  (goto-char (point-max))
	  (set-marker (process-mark process) (point))
	  (sit-for 0)			; update display
	  (accept-process-output process) ; wait for prompt
	  )
					;else - delete output from prior command, leaving cursor at end of command
      (beginning-of-line)
      (or (re-search-backward sqlplus-prompt-re (point-min) t)
	  (error "Nothing to kill"))
      (set-marker (process-mark process) (match-end 0))
      (sqlplus-get-command)    ; convenient way to find end of command
      (forward-char -1)			; back up one character
      (delete-region (point) (point-max))
      )					;end if
    )
  )

(defun sqlplus-get-command ()
  (interactive)
  (let ((line "") command-lines)
    (end-of-line)
    (or (re-search-backward sqlplus-prompt-re (point-min) t)
	(error "Unable to execute this command"))
    (goto-char (match-end 0))		; skip past prompt
    (setq command-lines		       ; initialize command-lines list
	  (if (looking-at "l$\\|list$\\|r$\\|run$\\|get .*\\|edit") ;ignore LIST,RUN,GET,EDIT
	      nil
	    (list (setq line 
			(buffer-substring (point) (progn (end-of-line) (point)))))
	    )
	  )
    (forward-line)
    (while (and				; while previous line 
	    (not (string-match "^\\(.*;$\\| */\\)$" line)) ; does not end in / or ;
	    (looking-at sqlplus-continue-pattern)) ; and this is a cont. line
      (goto-char (match-end 0))		; skip over prompt
      (setq line (buffer-substring (point) (progn (end-of-line) (point))))
      (setq command-lines (append command-lines (list line)))
      (forward-line)
      )
    command-lines          ; return command-lines as value of function
    ))

(defun sqlplus-interrupt-subjob ()
  "Interrupt this shell's current subjob.  This was modified by Thomas Miller
to actually run `kill' passing it -2, because interrupt-process seems to lock
this version of emacs up."
  (interactive)
  (let ((this-process (get-buffer-process (current-buffer))))
    (call-process "kill" nil t nil "-2"
		  (int-to-string (process-id this-process)))))

;; (defun sqlplus-interrupt-subjob ()
;;  "Interrupt this shell's current subjob."
;;  (interactive)
;;  (interrupt-process nil t))

(defun sqlplus-send-string (query)
  "Executes a particlur string (query) in the current SQL*Plus buffer."
  (let (process this-buffer temp-file-name start-query
		temp-buffer linsp)
    (setq this-buffer (current-buffer))
    (setq process (get-buffer-process this-buffer))
    (setq sqlplus-last-process-buffer (process-buffer process))
    ;; Create oracle-file-directory directory.
    (unless (file-exists-p oracle-file-directory)
      (make-directory oracle-file-directory t))
    (setq temp-file-name (expand-file-name (make-temp-name (concat oracle-file-directory "/sqlplus.buf"))))
    (write-region query nil temp-file-name nil 0)    
    (sqlplus-end-of-buffer)
    (recenter 0)
    (insert "\n")
    (set-marker (process-mark process) (point))
    (sit-for 0)				; update display
    (process-send-string process (concat "@" temp-file-name "\n"))
;;    (set-file-modes temp-file-name 700)
;;    (if temp-file-name (delete-file temp-file-name))
    (if temp-buffer (kill-buffer temp-buffer))
    (goto-char (point-max))))


(defun sqlplus-show-output ()
  "Display most recent batch of output at top of window.
Also put cursor there."
  (interactive)
  (goto-char sqlplus-last-output-start)
  )

(defun sqlplus-back-command (arg)
  "Move to the SQL*plus command before current position.
With prefix argument, move to ARG'th previous command."
  (interactive "p")
  (if (save-excursion 
	(beginning-of-line)
	(re-search-backward sqlplus-prompt-re (point-min) t arg))
      (goto-char (match-end 0))
    (error "No previous SQL*plus command.")))
  
(defun sqlplus-forward-command (arg)
  "Move to the SQL*plus command after current position.
With prefix argument, move to ARG'th previous command."
  (interactive "p")
  (if (re-search-forward sqlplus-prompt-re (point-max) t arg)
      nil
    (error "No next SQL*plus command.")))

(defun sqlplus-previous-command (arg)
  "Recall the previous SQL*plus command from the command stack.
With prefix argument, recall the command ARG commands before the current
stack pointer."
  (interactive "p")
					; - clear current pending command
  (goto-char (process-mark (get-buffer-process (current-buffer))))
  (delete-region (point) (point-max))

					; - increment stack pointer by arg
  (setq sqlplus-stack-pointer (+ sqlplus-stack-pointer arg))
  (if (< sqlplus-stack-pointer 0)
      (progn (setq sqlplus-stack-pointer 0)
	     (error "At last command.")))
					;if there is a prior command    
  (if (re-search-backward (concat sqlplus-prompt-re ".+") ; skip empty prompts
			  (point-min) t sqlplus-stack-pointer)
					;then
      (let ((command-lines (sqlplus-get-command)) col)
	(goto-char (point-max))
	(setq col (current-column))
	(while command-lines
	  (indent-to col)
	  (insert (car command-lines))
	  (setq command-lines (cdr command-lines))
	  (if command-lines (insert ?\n))
	  )
        (message (if (> sqlplus-stack-pointer 0)
		     (format "#%d" sqlplus-stack-pointer)
		   ""))
	)
					;else
    (setq sqlplus-stack-pointer (- sqlplus-stack-pointer arg)) ; reset
    (error "No previous SQL*plus command.")
    )
  )

(defun sqlplus-next-command (arg)
  "Recall the next SQL*plus command from the command stack.
With prefix argument, recall the command ARG commands after the current
stack pointer."
  (interactive "p")
  (sqlplus-previous-command (- arg)))

(defun sqlplus-end-of-buffer ()
  "Move cursor to end of buffer."
  (interactive)
  (goto-char (point-max)))

(defun sqlplus-reset-buffer ()
  "Reset SQL*Plus buffer to contain only command history, not output.
Commands of one or fewer characters (/, l, r, etc.) are not retained.
Also removes duplicate lines"
  (interactive)
  (sqlplus-clear-output)
  (sqlplus-clear-commands)
  (sqlplus-clear-prompts)
  ;;remove duplicates
  (let ((llist nil) (cplist nil) (klist nil) (done) (mark 1) (line))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
	(progn
	  (setq line (buffer-substring (save-excursion (beginning-of-line)
						       (point))
				       (save-excursion (end-of-line) (point))))
	  (setq cplist llist)
	  (setq done t)
	  (while (and cplist done)
	    (if (and (not (equal line "")) (equal line (car cplist)) (not
								      (equal line "#endif")))
		(progn
		  (setq klist (cons mark klist))
		  (setq done nil)))
	    (setq cplist (cdr cplist)))
	  (if done (setq llist (cons line llist)))
	  (forward-line 1)
	  (setq mark (+ mark 1)))))
    (save-excursion
      (goto-char (point-min))
      (while klist
	(progn
	  (goto-line (car klist))
	  (kill-line 1))
	(setq klist (cdr klist))))))

(defun sqlplus-clear-output ()
  "Reset SQL*Plus buffer to contain only command history, not output.
Commands of one or fewer characters (/, l, r, etc.) are not retained."
  (interactive)
  (let ((line "") (process (get-buffer-process (current-buffer))) start)
    (save-excursion
      (message "Deleting output lines...")
      (goto-char (point-min))
      (setq start (point))
      (while (re-search-forward (concat sqlplus-prompt-re "..+") (point-max) t)
	(goto-char (match-end 0))
	(setq line (buffer-substring (point) (progn (end-of-line) (point))))
	(beginning-of-line)
	(delete-region start (point))
	(forward-line)
	(while (and			; skip past SQL statement
		(not (string-match "^\\(.*;$\\| */\\)$" line))
		(looking-at sqlplus-continue-pattern)) ; and this is a cont. line
	  (goto-char (match-end 0))	; skip over prompt
	  (setq line (buffer-substring (point) (progn (end-of-line) (point))))
	  (forward-line)
	  )
	(setq start (point))
	)
      (goto-char (point-max))
      (delete-region start (point))
      (process-send-string process "\n") ; generate new SQL> prompt
      (goto-char (point-max))
      (set-marker (process-mark process) (point))
      (sit-for 0)			; update display
      (accept-process-output)		; wait for prompt
      (message "Deleting output lines...Done."))))


(defun sqlplus-clear-commands ()
  "Removes all lines that have SQLPLUS commands and comments."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    ;;(sleep-for 1)
    (delete-matching-lines (concat (downcase sqlplus-cmd-re) 
				   ".*$" "\\|" 
				   (downcase sqlplus-prompt-re) 
				   oracle-comment-start-re))))

(defun sqlplus-clear-dangerous-sql ()
  "Removes all lines that have SQLPLUS commands and comments."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    ;;(sleep-for 1)
    (delete-matching-lines sqlplus-dangerous-sql-re)))


(defun sqlplus-drop-old-lines (lines-to-keep)
  "Delete old lines from current buffer.
Number of lines to keep is determined by the variable sqlplus-lines-to-keep.
With prefix argument, keep the last ARG lines."
  (interactive "P")
  (delete-region (save-excursion
		   (goto-char (point-min))
		   (point))
		 (save-excursion
		   (goto-char (point-max))
		   (forward-line (- (or lines-to-keep 
					sqlplus-lines-to-keep 
					1000)))
		   (point)))
  )

(defun sqlplus-save-session (filename)
  "Save current SQL*Plus session to FILENAME."
  (interactive "FFile to save session to: ")	    
  (save-excursion
    (if (or (null filename) (string= filename ""))
	;; Create oracle-file-directory directory.
	(unless (file-exists-p oracle-file-directory)
	  (make-directory oracle-file-directory t))
      (setq filename (concat oracle-file-directory "/" sqlplus-history-file)))
    (message (format "Saving %s..." filename))
    (write-region (progn
		    (goto-char (point-min))
		    (re-search-forward sqlplus-prompt-re (point-max) t)
		    (match-end 0))
		  (progn
		    (goto-char (point-max))
		    (re-search-backward sqlplus-prompt-re (point-min) t)
		    (match-end 0))
		  (expand-file-name filename) nil 0)
    (message (format "Saving %s...done" filename))))


(defun sqlplus-load-session ()
  "Load `sqlplus-history-file' file into the current session."
  (interactive)
  (if (file-readable-p (expand-file-name (concat oracle-file-directory "/" sqlplus-history-file)))
      (progn
	(insert (concat sqlplus-prompt " "))
	(insert-file-contents (expand-file-name (concat oracle-file-directory "/" sqlplus-history-file)) nil)
	(goto-char (point-max))
	;;(toggle-truncate-lines) ;; this needs to be used for Emacs 21
	(message "History file loaded")
	)
  (message "The history file is not readable" )))


(defun sqlplus-copy-word ()
  "Copy current word to the end of buffer, inserting SELECT keyword 
or commas if appropriate."
  (interactive)
  (let (word preceding-word)
    (save-excursion
      (setq word (buffer-substring	; extract word
		  (progn (forward-char 1) (backward-word 1) (point))
		  (progn (forward-word 1) (point))))
      (goto-char (point-max))		; goto end of buffer
      (cond
					; sitting at empty command line
       ((save-excursion (beginning-of-line) 
			(looking-at (concat sqlplus-prompt-re "$")))
	(insert "SELECT ")
	)
					; on same line as SELECT or ORDER BY, but other words already inserted
       ((save-excursion (re-search-backward " select .+\\| order by .+" 
					    (save-excursion (beginning-of-line) (point)) t))
	(insert ", ")
	)
					; Otherwise
       (t
	(if (eq (preceding-char) ? )  ; if preceding character = space
	    nil
	  (insert " ")
	  )
	)
       )				;end case
      (insert word)
      (message (format "\"%s\" copied" word))
      )
    )
  )


(defun sqlplus-tablespace-ddl ()
  "Uses DBMS_METADATA to extract DDL for any word the cursor is currently on.
This function assumes that the word is a tablespace, so it uses the ALL_TABLESPACES table
to find the object.

This default behavior can be changed by customizing the variable sqlplus-dict-prefix. For
example, if sqlplus-dict-prefiex were set to \"DBA\", then SELECT_CATALOG_ROLE would
enable a user to see any object.

The object views of the Oracle metadata model implement security as follows:

-Nonprivileged users can see the metadata of only their own objects.
-Nonprivileged users can also retrieve public synonyms, system privileges granted to them, and object 
 privileges granted to them or by them to others. Any one can see privileges granted to PUBLIC.
-If callers request objects they are not privileged to retrieve, no exception is raised; the object
 is simply not retrieved.
-If nonprivileged users are granted some form of access to an object in someone else's schema, 
 they will be able to retrieve the grant specification through the Metadata API, but not the object's actual metadata.
-In stored procedures, functions, and definers-rights packages, roles (such as SELECT_CATALOG_ROLE) are disabled. Therefore, 
 such a PL/SQL program can only fetch metadata for objects in its own schema."
  (interactive)
  (sqlplus-extract-object)
  (sqlplus-send-string sqlplus-tablespace-ddl-query))

(defun sqlplus-user-ddl ()
  "Uses DBMS_METADATA to extract DDL for any word the cursor is currently on.
This function assumes that the word is a user, so it uses the ALL_USERS table
to find the object.

This default behavior can be changed by customizing the variable sqlplus-dict-prefix. For
example, if sqlplus-dict-prefiex were set to \"DBA\", then SELECT_CATALOG_ROLE would
enable a user to see any object.

The object views of the Oracle metadata model implement security as follows:

-Nonprivileged users can see the metadata of only their own objects.
-Nonprivileged users can also retrieve public synonyms, system privileges granted to them, and object 
 privileges granted to them or by them to others. Any one can see privileges granted to PUBLIC.
-If callers request objects they are not privileged to retrieve, no exception is raised; the object
 is simply not retrieved.
-If nonprivileged users are granted some form of access to an object in someone else's schema, 
 they will be able to retrieve the grant specification through the Metadata API, but not the object's actual metadata.
-In stored procedures, functions, and definers-rights packages, roles (such as SELECT_CATALOG_ROLE) are disabled. Therefore, 
 such a PL/SQL program can only fetch metadata for objects in its own schema.

This function was developed and tested against Oracle 10g only."
  (interactive)
  (sqlplus-extract-object)
  (sqlplus-send-string sqlplus-user-ddl-query))


(defun sqlplus-object-ddl ()
  "Uses DBMS_METADATA to extract DDL for any word the cursor is currently on.
Looks in the ALL_OBJECTS table for any object the connected user has permissions to see.

This default behavior can be changed by customizing the variable sqlplus-dict-prefix. For
example, if sqlplus-dict-prefiex were set to \"DBA\", then SELECT_CATALOG_ROLE would
enable a user to see any object.

The object views of the Oracle metadata model implement security as follows:

-Nonprivileged users can see the metadata of only their own objects.
-Nonprivileged users can also retrieve public synonyms, system privileges granted to them, and object 
 privileges granted to them or by them to others. Any one can see privileges granted to PUBLIC.
-If callers request objects they are not privileged to retrieve, no exception is raised; the object
 is simply not retrieved.
-If nonprivileged users are granted some form of access to an object in someone else's schema, 
 they will be able to retrieve the grant specification through the Metadata API, but not the object's actual metadata.
-In stored procedures, functions, and definers-rights packages, roles (such as SELECT_CATALOG_ROLE) are disabled. Therefore, 
 such a PL/SQL program can only fetch metadata for objects in its own schema.

This function was developed and tested against Oracle 10g only."
  (interactive)
  (sqlplus-extract-object)
  (sqlplus-send-string sqlplus-object-ddl-query))


(defun sqlplus-index-ddl ()
  "Uses DBMS_METADATA to extract the DDL for the indexes of any table name the cursor is 
currently on. Looks in the ALL_INDEXES table for any table name the connected user has 
permissions to see.

This default behavior can be changed by customizing the variable sqlplus-dict-prefix. For
example, if sqlplus-dict-prefiex were set to \"DBA\", then SELECT_CATALOG_ROLE would
enable a user to see any object.

The object views of the Oracle metadata model implement security as follows:

-Nonprivileged users can see the metadata of only their own objects.
-Nonprivileged users can also retrieve public synonyms, system privileges granted to them, and object 
 privileges granted to them or by them to others. Any one can see privileges granted to PUBLIC.
-If callers request objects they are not privileged to retrieve, no exception is raised; the object
 is simply not retrieved.
-If nonprivileged users are granted some form of access to an object in someone else's schema, 
 they will be able to retrieve the grant specification through the Metadata API, but not the object's actual metadata.
-In stored procedures, functions, and definers-rights packages, roles (such as SELECT_CATALOG_ROLE) are disabled. Therefore, 
 such a PL/SQL program can only fetch metadata for objects in its own schema.

This function was developed and tested against Oracle 10g only."
  (interactive)
  (sqlplus-extract-object)
  (sqlplus-send-string sqlplus-index-ddl-query))

(defun sqlplus-current-schema ()
  "Set the CURRENT_SCHEMA parameter to a value provided by the user."
  (interactive)
  (sqlplus-send-string (concat "alter session set current_schema=" (read-string "Enter schema: ") ";")))

(defun sqlplus-desc ()
  "Uses `sqlplus-desc-query' to enhance the DESCRIBE command for a table."
  (interactive)
  (sqlplus-extract-owner-object)
  (sqlplus-send-string sqlplus-desc-query))


(defun sqlplus-desc-tab ()
  "Uses `sqlplus-desc-tab-query' to enhance the DESCRIBE command for a table."
  (interactive)
  (sqlplus-extract-owner-object)
  (sqlplus-send-string sqlplus-desc-tab-query))


(defun sqlplus-sid-serial ()
  "Extracts the sid and serial# from a particular line out output
in SQL*Plus. It then sets the SQL*Plus variables &sid and &serial equal
to what was extracted.

Looks for a pattern matching \"(sid,serial#)\", which is the common
output from functions such as `sqlplus-sessions'."
  (interactive)
  (let ((sid) (serial))
    (beginning-of-line)
    (setq sid (buffer-substring	;; extract the first number
	       (progn (beginning-of-line)
		      (re-search-forward "(")
		      (point))
	       (progn (forward-word 1)
		      (point))))
    (setq serial (buffer-substring ;; extract second number
		  (progn (beginning-of-line)
			 (re-search-forward "\\,")
			 (point))
		  (progn (forward-word 1)
			 (point))))
    (sqlplus-send-string (concat "DEFINE sid = " sid "\nDEFINE serial = " serial))))

(defun sqlplus-extract-object ()
  "Extracts an object name from the current cursor position
in SQL*Plus. It then sets the SQL*Plus variable &object equal
to what was extracted."
  (interactive)
  (let ((object))
    (save-excursion
      (setq object (buffer-substring	; extract word
		  (progn (forward-char 1) (backward-word 1) (point))
		  (progn (forward-word 1)
			 (if (looking-at "\\.")
			     (forward-word 1))
			 (point))))
      (sqlplus-send-string (concat "DEFINE object = " object)))))

(defun sqlplus-extract-owner-object ()
  "Extracts an object name from the current cursor position
in SQL*Plus. It then sets the SQL*Plus variable &object equal
to what was extracted."
  (interactive)
  (let ((object))
    (save-excursion
      (setq object (buffer-substring	; extract word
		  (progn (forward-char 1)
			 (backward-word 1)
			 (if (save-excursion
			       (backward-char 1)
			       (looking-at "\\."))
			     (backward-word 1))
			 (point))
		  (progn (forward-word 1)
			 (if (looking-at "\\.")
			     (forward-word 1))
			 (point))))
      (sqlplus-send-string (concat "DEFINE object = " object)))))


(defun sqlplus-echo-on ()
  "Sets echo on for a SQL*Plus session."
  (interactive)
  (sqlplus-send-string (concat "set echo on")))

(defun sqlplus-sessions ()
  "Shows sessions currently connected."
  (interactive)
  (sqlplus-send-string sqlplus-sessions-query))

(defun sqlplus-current-sql ()
  "Shows executing sql for a particular session extracted using `sqlplus-sid-serial'."
  (interactive)
  (sqlplus-sid-serial)
  (sqlplus-send-string sqlplus-current-sql-query))

(defun sqlplus-waits ()
  "Shows waits for a particular session extracted using `sqlplus-sid-serial'."
  (interactive)
  (sqlplus-sid-serial)
  (sqlplus-send-string sqlplus-waits-query))

(defun sqlplus-waits-px ()
  "Shows waits for a particular session extracted using `sqlplus-sid-serial'."
  (interactive)
  (sqlplus-sid-serial)
  (sqlplus-send-string sqlplus-waits-px-query))


(defun sqlplus-longops ()
  "Shows long operations for a particular session extracted using
`sqlplus-sid-serial'."
  (interactive)
  (sqlplus-sid-serial)
  (sqlplus-send-string sqlplus-longops-query))

(defun sqlplus-longops-px ()
  "Extracts the sid/serial combination for a particular session using
`sqlplus-sid-serial'. Then, a query is executed that display ALL the long
operations executed by a parallel query group that the particular session
may be a member of."
  (interactive)
  (sqlplus-sid-serial)
  (sqlplus-send-string sqlplus-longops-px-query))

(require 'assoc)

(defun sqlplus-choose-process ()
  "Present a list of all buffer whose process = `SQL*Plus', and let the user
choose from this list.  A default buffer is presented if this has been run
before.

This function was added to sql-mode.el by Thomas Miller and is included here."
  (let ((working-process-list (process-list))
	sqlplus-buffer-alist
	chosen-buffer
	process)
    (while (car working-process-list)
      (let ((process (car working-process-list)))
	(if (string-match "SQL\\*plus.*" (process-name process))
	    (aput 'sqlplus-buffer-alist (buffer-name
					 (process-buffer process))))
	(setq working-process-list (cdr working-process-list))))
    ;; If no processes found, just start a new one.
    (if (not sqlplus-buffer-alist)
	(or (setq process (sqlplus-start))
	    (error "Unable to create SQL*plus session."))
      (let ((chosen-buffer
	     (completing-read "Choose a SQL*Plus buffer to run in: "
			      sqlplus-buffer-alist
			      nil nil
			      (if sqlplus-last-process-buffer
				  (buffer-name sqlplus-last-process-buffer)
				nil))))
	(if (string= chosen-buffer "")
	    (or (setq process (sqlplus-start))
		(error "Unable to create SQL*plus session."))
	  (setq process (get-buffer-process chosen-buffer)))))
    process))

(require 'dired)

(defun tkprof ()
  "Format a trace file (locally or from a tramp buffer) and open it locally"
  (interactive)
  (let ((absolute-trace-file (dired-get-filename))
	output-file
	tkprof-parms-string
	tkprof-buffer
	process
	trace-file
	absolute-trace-filebase
	trace-filebase)
    (setq trace-file (file-name-nondirectory absolute-trace-file))
    (setq trace-filebase (file-name-sans-extension trace-file))
    (setq absolute-trace-filebase (file-name-sans-extension absolute-trace-file))
    (while (string-match "@" absolute-trace-file)
      (copy-file trace-file (expand-file-name (concat tkprof-directory "/" trace-file)) 1)
      (setq absolute-trace-file (expand-file-name (concat tkprof-directory "/" trace-file)))
      (set-buffer (find-file absolute-trace-file))
      (setq absolute-trace-filebase (expand-file-name (concat tkprof-directory "/" trace-filebase))))
    (setq output-file (expand-file-name (concat tkprof-directory "/" trace-filebase ".out"))
	  tkprof-parms-string (concat absolute-trace-file " " output-file 
				      " waits=" tkprof-waits 
				      " sys=" tkprof-sys 
				      " aggregate=" tkprof-aggregate 
				      " sort=" tkprof-sort))
    (setq process (start-process "tkprof" "*tkprof*" "tkprof" tkprof-parms-string))
    (accept-process-output process)
    ;;    (shell-command (concat "tkprof " tkprof-parms-string))
    (find-file output-file)))

(defun tkprof-navigator ()
  "Use `occur' to create sql statement navigator menu in a side window"
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward tkprof-statement-re nil t)
	(progn (split-window-horizontally (/ (frame-width) tkprof-statement-nav-ratio))
	       (other-window 1)
	       (occur tkprof-statement-re tkprof-statement-nav-nlines)
	       (other-window 1))
      (message "No SQL statements found"))))

(defun oracle-plsql-wrap (wrap-file)
  "Wrap PL/SQL code in current file to another file in directory specified by WRAP-FILE"
  (interactive "FFile to wrap code to:")
  (let ((ifile-path (buffer-file-name (current-buffer)))
	ifile-sans-ext
	ifile-sans-ext-and-dir
	ofile-path
	process
	iname-parm
	oname-parm
	wrap-parms-string)
    (setq ifile-sans-ext (file-name-sans-extension ifile-path))
    (setq ifile-sans-ext-and-dir (file-name-nondirectory ifile-sans-ext))
    (setq iname-parm (concat "iname=" ifile-path))
    (setq oname-parm (concat "oname=" (expand-file-name wrap-file)))
    (setq process (start-process "wrap" "*wrap*" "wrap" iname-parm oname-parm))
    (accept-process-output process)
    (message (concat "Wrap process executed"))))


;;; provide ourself

(provide 'oracle-mode)

;;; oracle.el ends here
