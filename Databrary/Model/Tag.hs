{-# LANGUAGE TemplateHaskell, QuasiQuotes, RecordWildCards, OverloadedStrings #-}
module Databrary.Model.Tag
  ( module Databrary.Model.Tag.Types
  , lookupTag
  , addTag
  , addTagUse
  , removeTagUse
  , lookupSlotTagCoverage
  , tagCoverageJSON
  ) where

import Control.Monad (guard)
import Data.Int (Int64)
import Data.Maybe (catMaybes)
import Database.PostgreSQL.Typed (pgSQL)

import Databrary.Ops
import qualified Databrary.JSON as JSON
import Databrary.DB
import Databrary.Model.SQL
import Databrary.Model.Party.Types
import Databrary.Model.Container.Types
import Databrary.Model.Slot.Types
import Databrary.Model.Tag.Types
import Databrary.Model.Tag.SQL

useTPG

lookupTag :: DBM m => TagName -> m (Maybe Tag)
lookupTag n =
  dbQuery1 $(selectQuery selectTag "$WHERE tag.name = ${n}::varchar")

addTag :: DBM m => TagName -> m Tag
addTag n =
  dbQuery1' $ (`Tag` n) <$> [pgSQL|!SELECT get_tag(${n})|]

addTagUse :: DBM m => TagUse -> m Bool
addTagUse t =
  either (const False) ((0 <) . fst) <$> dbTryQuery (guard . isExclusionViolation)
    (if tagKeyword t
      then $(insertTagUse True 't)
      else $(insertTagUse False 't))

removeTagUse :: DBM m => TagUse -> m Bool
removeTagUse t =
  (0 <) <$> dbExecute
    (if tagKeyword t 
      then $(deleteTagUse True 't)
      else $(deleteTagUse False 't))

lookupSlotTagCoverage :: DBM m => Party -> Slot -> Int -> m [TagCoverage]
lookupSlotTagCoverage acct slot lim =
  dbQuery $(selectSlotTagCoverage 'acct 'slot >>= (`selectQuery` "$!ORDER BY weight DESC LIMIT ${fromIntegral lim :: Int64}"))

tagCoverageJSON :: TagCoverage -> JSON.Object
tagCoverageJSON TagCoverage{..} = JSON.record (tagName tagCoverageTag) $ catMaybes
  [ Just $ "weight" JSON..= tagCoverageWeight
  , Just $ "coverage" JSON..= tagCoverageSegments
  , null tagCoverageKeywords ?!> "keyword" JSON..= tagCoverageKeywords
  , null tagCoverageVotes ?!> "vote" JSON..= tagCoverageVotes
  ]
