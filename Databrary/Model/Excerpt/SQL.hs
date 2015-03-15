{-# LANGUAGE TemplateHaskell #-}
module Databrary.Model.Excerpt.SQL
  ( selectAssetSlotExcerpt
  , insertExcerpt
  , updateExcerpt
  , deleteExcerpt
  ) where

import qualified Language.Haskell.TH as TH

import Databrary.Model.SQL.Select
import Databrary.Model.Audit.SQL
import Databrary.Model.Permission.Types
import Databrary.Model.Time.Types
import Databrary.Model.AssetSlot.Types
import Databrary.Model.Excerpt.Types

makeExcerpt :: Segment -> Classification -> AssetSlot -> Excerpt
makeExcerpt s c a = Excerpt a s c

excerptRow :: Selector -- ^ @'AssetSlot' -> 'Excerpt'@
excerptRow = selectColumns 'makeExcerpt "excerpt" ["segment", "classification"]

selectAssetSlotExcerpt :: Selector -- ^ @'AssetSlot' -> 'Excerpt'@
selectAssetSlotExcerpt = excerptRow

excerptKeys :: String -- ^ @'Excerpt'@
  -> [(String, String)]
excerptKeys o =
  [ ("asset", "${assetId $ slotAsset $ excerptAsset " ++ o ++ "}")
  , ("segment", "${excerptSegment " ++ o ++ "}")
  ]

excerptSets :: String -- ^ @'Excerpt'@
  -> [(String, String)]
excerptSets o =
  [ ("classification", "${excerptClassification " ++ o ++ "}")
  ]

insertExcerpt :: TH.Name -- ^ @'AuditIdentity'@
  -> TH.Name -- ^ @'Excerpt'@
  -> TH.ExpQ
insertExcerpt ident o = auditInsert ident "excerpt"
  (excerptKeys os ++ excerptSets os)
  Nothing
  where os = nameRef o

updateExcerpt :: TH.Name -- ^ @'AuditIdentity'@
  -> TH.Name -- ^ @'Excerpt'@
  -> TH.ExpQ
updateExcerpt ident o = auditUpdate ident "excerpt"
  (excerptSets os)
  (whereEq $ excerptKeys os)
  Nothing
  where os = nameRef o

deleteExcerpt :: TH.Name -- ^ @'AuditIdentity'@
  -> TH.Name -- ^ @'Excerpt'@
  -> TH.ExpQ
deleteExcerpt ident o = auditDelete ident "excerpt"
  ("asset = ${assetId $ slotAsset $ excerptAsset " ++ os ++ "} AND segment <@ ${excerptSegment " ++ os ++ "}")
  Nothing
  where os = nameRef o