{-# LANGUAGE TemplateHaskell, OverloadedStrings #-}
module Databrary.Model.Record.SQL
  ( selectVolumeRecord
  , selectRecord
  , insertRecord
  , updateRecord
  , deleteRecord
  ) where

import qualified Data.ByteString.Char8 as BSC
import Data.Maybe (fromMaybe)
import qualified Language.Haskell.TH as TH

import Databrary.Model.SQL.Select
import Databrary.Model.Audit.SQL
import Databrary.Model.Id.Types
import Databrary.Model.Release.Types
import Databrary.Model.Volume.Types
import Databrary.Model.Volume.SQL
import Databrary.Model.RecordCategory
import Databrary.Model.Metric
import Databrary.Model.Record.Types

parseMeasure :: Record -> BSC.ByteString -> Measure
parseMeasure r s = Measure r (getMetric' (Id (read (BSC.unpack m)))) (BSC.tail d) where
  (m, d) = BSC.splitAt (fromMaybe (error $ "parseMeasure " ++ show (recordId r) ++ ": " ++ BSC.unpack s) $ BSC.elemIndex ':' s) s

makeRecord :: Id Record -> Maybe (Id RecordCategory) -> [Maybe BSC.ByteString] -> Maybe Release -> Volume -> Record
makeRecord i c ms p v = r where
  r = Record i v (fmap getRecordCategory' c) p (map (parseMeasure r . fromMaybe (error "NULL record.measure")) ms)

recordRow :: Selector -- ^ @Maybe 'Release' -> 'Volume' -> 'Record'@
recordRow = fromMap ("record_measures AS " ++) $
  selectColumns 'makeRecord "record" ["id", "category", "measures"]

selectVolumeRecord :: Selector -- ^ @'Volume' -> 'Record'@
selectVolumeRecord = addSelects '($) recordRow ["record_release(record.id)"]

selectRecord :: TH.Name -- ^ @'Identity'@
  -> Selector -- ^ @'Record'@
selectRecord ident = selectJoin '($)
  [ selectVolumeRecord
  , joinOn "record.volume = volume.id" $ selectVolume ident
  ]

recordKeys :: String -- ^ @'Record'@
  -> [(String, String)]
recordKeys r =
  [ ("id", "${recordId " ++ r ++ "}") ]

recordSets :: String -- ^ @'Record'@
  -> [(String, String)]
recordSets r =
  [ ("volume", "${volumeId (recordVolume " ++ r ++ ")}")
  , ("category", "${fmap recordCategoryId (recordCategory " ++ r ++ ")}")
  ]

setRecordId :: Record -> Id Record -> Record
setRecordId r i = r{ recordId = i }

insertRecord :: TH.Name -- ^ @'AuditIdentity'@
  -> TH.Name -- ^ @'Record'@
  -> TH.ExpQ -- ^ @'Record'@
insertRecord ident r = auditInsert ident "record"
  (recordSets (nameRef r))
  (Just $ selectOutput $ selectMap ((TH.VarE 'setRecordId `TH.AppE` TH.VarE r) `TH.AppE`) $ selector "record" "id")

updateRecord :: TH.Name -- ^ @'AuditIdentity'@
  -> TH.Name -- ^ @'Record'@
  -> TH.ExpQ -- ^ @()@
updateRecord ident r = auditUpdate ident "record"
  (recordSets (nameRef r))
  (whereEq $ recordKeys (nameRef r))
  Nothing

deleteRecord :: TH.Name -- ^ @'AuditIdentity'@
  -> TH.Name -- ^ @'Record'@
  -> TH.ExpQ -- ^ @()@
deleteRecord ident r = auditDelete ident "record"
  (whereEq $ recordKeys (nameRef r))
  Nothing
