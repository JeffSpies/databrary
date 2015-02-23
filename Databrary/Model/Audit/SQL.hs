{-# LANGUAGE TemplateHaskell #-}
module Databrary.Model.Audit.SQL
  ( auditInsert
  , auditDelete
  , auditUpdate
  , whereEq
  ) where

import Data.List (intercalate)
import Database.PostgreSQL.Typed.Query (makePGQuery, simpleQueryFlags)
import Database.PostgreSQL.Typed.Dynamic (pgSafeLiteral)
import qualified Language.Haskell.TH as TH

import Databrary.Model.SQL.Select
import Databrary.Model.Audit.Types

actionCmd :: AuditAction -> String
actionCmd AuditActionAdd = "INSERT INTO"
actionCmd AuditActionChange = "UPDATE"
actionCmd AuditActionRemove = "DELETE FROM"
actionCmd a = error $ "actionCmd: " ++ show a

auditQuery :: AuditAction -> TH.Name -- ^ @'AuditIdentity'
  -> String -> String -> Maybe SelectOutput -> TH.ExpQ
auditQuery action ident table stmt =
  maybe (makePGQuery flags sql) (makeQuery flags ((sql ++) . (" RETURNING " ++)))
  where
  sql = "WITH audit_row AS (" ++ actionCmd action ++ ' ' : table ++ ' ' : stmt
    ++ " RETURNING *) INSERT INTO audit." ++ table
    ++ " SELECT CURRENT_TIMESTAMP, ${auditWho " ++ idents ++ "}, ${auditIp " ++ idents ++ "}, " ++ pgSafeLiteral action ++ ", * FROM audit_row"
  idents = nameRef ident
  flags = simpleQueryFlags

auditInsert :: TH.Name -> String -> [(String, String)] -> Maybe SelectOutput -> TH.ExpQ
auditInsert ident table args =
  auditQuery AuditActionAdd ident table 
    ('(' : intercalate "," (map fst args) ++ ") VALUES (" ++ intercalate "," (map snd args) ++ ")")

auditDelete :: TH.Name -> String -> String -> Maybe SelectOutput -> TH.ExpQ
auditDelete ident table wher =
  auditQuery AuditActionRemove ident table ("WHERE " ++ wher)

auditUpdate :: TH.Name -> String -> [(String, String)] -> String -> Maybe SelectOutput -> TH.ExpQ
auditUpdate ident table sets wher =
  auditQuery AuditActionChange ident table
    ("SET " ++ intercalate "," (map pairEq sets) ++ " WHERE " ++ wher)

pairEq :: (String, String) -> String
pairEq (c, v) = c ++ "=" ++ v

whereEq :: [(String, String)] -> String
whereEq = intercalate " AND " . map pairEq
