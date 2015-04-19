{-# LANGUAGE OverloadedStrings, PatternGuards #-}
module Databrary.Controller.Analytics
  ( angularAnalytics
  ) where

import Control.Applicative ((<$>), (<*>))
import Control.Monad (when)
import qualified Data.Attoparsec.ByteString as P
import qualified Data.Foldable as Fold
import qualified Data.HashMap.Strict as HM
import Data.Maybe (mapMaybe, maybeToList)
import qualified Data.Vector as V

import Databrary.Has (peek)
import qualified Databrary.JSON as JSON
import Databrary.Model.Audit
import Databrary.HTTP.Request

angularAnalytics :: MonadAudit q m => m ()
angularAnalytics = do
  req <- peek
  when (Fold.any ("DatabraryClient" ==) $ lookupRequestHeader "x-requested-with" req) $
    mapM_ auditAnalytic $ pr . P.parseOnly JSON.json' =<< lookupRequestHeaders "analytics" req
  where
  pr (Left _) = []
  pr (Right (JSON.Array l)) = mapMaybe ar $ V.toList l
  pr (Right j) = maybeToList $ ar j
  ar (JSON.Object o) = Analytic 
    <$> (JSON.parseMaybe JSON.parseJSON =<< HM.lookup "action" o)
    <*> (JSON.parseMaybe JSON.parseJSON =<< HM.lookup "route" o)
    <*> HM.lookup "data" o
  ar _ = Nothing
