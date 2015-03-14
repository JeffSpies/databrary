{-# LANGUAGE OverloadedStrings, TemplateHaskell #-}
module Databrary.Model.Measure
  ( getRecordMeasures
  , getMeasure
  , changeRecordMeasure
  , removeRecordMeasure
  , decodeMeasure
  , measuresJSON
  ) where

import Control.Monad (guard)
import Data.Function (on)
import Data.List (find)
import qualified Data.Text as T
import Database.PostgreSQL.Typed.Protocol (PGError(..), pgErrorCode)
import Database.PostgreSQL.Typed.Types (PGTypeName, pgTypeName, PGColumn(pgDecode))

import Control.Applicative.Ops
import Control.Has (view)
import Databrary.DB
import qualified Databrary.JSON as JSON
import Databrary.Model.SQL
import Databrary.Model.Permission
import Databrary.Model.Audit
import Databrary.Model.Metric
import Databrary.Model.Record.Types
import Databrary.Model.Measure.SQL

measureOrder :: Measure -> Measure -> Ordering
measureOrder = compare `on` (metricId . measureMetric)

getMeasure :: Metric -> Measures -> Maybe Measure
getMeasure m = find ((metricId m ==) . metricId . measureMetric)

rmMeasure :: Measure -> Record
rmMeasure m@Measure{ measureRecord = rec } = rec{ recordMeasures = upd $ recordMeasures rec } where
  upd [] = [m]
  upd l@(m':l') = case m `measureOrder` m' of
    GT -> m':upd l'
    EQ -> l'
    LT -> l

upMeasure :: Measure -> Record
upMeasure m@Measure{ measureRecord = rec } = rec{ recordMeasures = upd $ recordMeasures rec } where
  upd [] = [m]
  upd l@(m':l') = case m `measureOrder` m' of
    GT -> m':upd l'
    EQ -> m:l'
    LT -> m:l

isInvalidInputException :: PGError -> Bool
isInvalidInputException e = pgErrorCode e `elem` ["22007", "22008", "22P02"]

changeRecordMeasure :: MonadAudit c m => Measure -> m (Maybe Record)
changeRecordMeasure m = do
  ident <- getAuditIdentity
  r <- tryUpdateOrInsert (guard . isInvalidInputException)
    $(updateMeasure 'ident 'm)
    $(insertMeasure 'ident 'm)
  case r of
    Left () -> return Nothing
    Right (_, [d]) -> return $ Just $ upMeasure d
    Right (n, _) -> fail $ "changeRecordMeasure: " ++ show n ++ " rows"

removeRecordMeasure :: MonadAudit c m => Measure -> m Record
removeRecordMeasure m = do
  ident <- getAuditIdentity
  r <- dbExecute $(deleteMeasure 'ident 'm)
  return $ if r > 0
    then rmMeasure m
    else measureRecord m

getRecordMeasures :: Record -> Measures
getRecordMeasures r = maybe [] filt $ readClassification (view r) (view r) where
  filt c = filter ((>= c) . view) $ recordMeasures r

decodeMeasure :: PGColumn t d => PGTypeName t -> Measure -> Maybe d
decodeMeasure t Measure{ measureMetric = Metric{ metricType = m }, measureDatum = d } =
  pgTypeName t == show m ?> pgDecode t d

measureJSONPair :: Measure -> JSON.Pair
measureJSONPair m = T.pack (show (metricId (measureMetric m))) JSON..= measureDatum m

measuresJSON :: Measures -> JSON.Object
measuresJSON = JSON.object . map measureJSONPair
