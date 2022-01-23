/* sqlite3 用 data.sqlite3 ファイルのデータベース作成 SQL ファイル */
/* 使い方： sqlite3 .read [THIS SQL FILE] */
CREATE TABLE graphdata(
datatime INTEGER NOT NULL,
temp_sys INTEGER,
temp_room INTEGER,
humid INTEGER,
pressure INTEGER);
