{-# LANGUAGE TemplateHaskell, OverloadedStrings #-}
module Databrary.Model.Container.SQL
  ( selectVolumeContainer
  , selectContainer
  , insertContainer
  , updateContainer
  , deleteContainer
  ) where

import qualified Language.Haskell.TH as TH

import Databrary.Model.SQL.Select
import Databrary.Model.Id.Types
import Databrary.Model.Audit.SQL
import Databrary.Model.Volume.SQL
import Databrary.Model.Consent.SQL
import Databrary.Model.Container.Types

containerRow :: Selector -- ^ @Maybe 'Consent' -> 'Permission' -> 'Container'@
containerRow = selectColumns 'Container "container" ["id", "top", "name", "date"]

selectVolumeContainer :: Selector -- ^ @'Volume' -> 'Container'@
selectVolumeContainer = selectJoin '($)
  [ containerRow
  , maybeJoinOn "container.id = slot_consent.container AND slot_consent.segment = '(,)'"
    consentRow
  ]

selectContainer :: TH.Name -- ^ @'Identity'@
  -> Selector -- ^ @'Container'@
selectContainer ident = selectJoin '($)
  [ selectVolumeContainer
  , joinOn "container.volume = volume.id" $ selectVolume ident
  ]

containerKeys :: String -- ^ @'Container'@
  -> [(String, String)]
containerKeys o =
  [ ("id", "${containerId " ++ o ++ "}") ]

containerSets :: String -- ^ @'Container'@
  -> [(String, String)]
containerSets o =
  [ ("volume", "${volumeId (containerVolume " ++ o ++ ")}")
  , ("top", "${containerTop " ++ o ++ "}")
  , ("name", "${containerName " ++ o ++ "}")
  , ("date", "${containerDate " ++ o ++ "}")
  ]

setContainerId :: Container -> Id Container -> Container
setContainerId o i = o{ containerId = i }

insertContainer :: TH.Name -- ^ @'AuditIdentity'@
  -> TH.Name -- ^ @'Container'@
  -> TH.ExpQ -- ^ @'Container'@
insertContainer ident o = auditInsert ident "container"
  (containerKeys (nameRef o) ++ containerSets (nameRef o))
  (Just $ selectOutput $ selectMap ((TH.VarE 'setContainerId `TH.AppE` TH.VarE o) `TH.AppE`) $ selector "container" "id")

updateContainer :: TH.Name -- ^ @'AuditIdentity'@
  -> TH.Name -- ^ @'Container'@
  -> TH.ExpQ -- ^ @()@
updateContainer ident o = auditUpdate ident "container"
  (containerSets (nameRef o))
  (whereEq $ containerKeys (nameRef o))
  Nothing

deleteContainer :: TH.Name -- ^ @'AuditIdentity'@
  -> TH.Name -- ^ @'Container'@
  -> TH.ExpQ -- ^ @()@
deleteContainer ident o = auditDelete ident "container"
  (whereEq $ containerKeys (nameRef o))
  Nothing

