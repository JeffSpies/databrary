{-# LANGUAGE OverloadedStrings, RecordWildCards, TemplateHaskell, QuasiQuotes #-}
module Databrary.Model.Asset
  ( module Databrary.Model.Asset.Types
  , blankAsset
  , lookupAsset
  , addAsset
  , changeAsset
  , supersedeAsset
  , assetIsSuperseded
  , assetCreation
  , assetJSON
  ) where

import Control.Arrow (first)
import Data.Maybe (catMaybes, isNothing)
import qualified Data.Text as T
import Database.PostgreSQL.Typed (pgSQL)

import Databrary.Ops
import Databrary.Has (view, peek)
import qualified Databrary.JSON as JSON
import Databrary.Service.DB
import Databrary.Store
import Databrary.Store.Types
import Databrary.Store.Asset
import Databrary.Model.SQL
import Databrary.Model.Time
import Databrary.Model.Audit
import Databrary.Model.Id
import Databrary.Model.Identity
import Databrary.Model.Party
import Databrary.Model.Volume
import Databrary.Model.Format
import Databrary.Model.Asset.Types
import Databrary.Model.Asset.SQL

useTPG

blankAsset :: Volume -> Asset
blankAsset vol = Asset
  { assetId = error "blankAsset"
  , assetFormat = unknownFormat
  , assetRelease = Nothing
  , assetName = Nothing
  , assetDuration = Nothing
  , assetSHA1 = Nothing
  , assetSize = Nothing
  , assetVolume = vol
  }

lookupAsset :: (MonadHasIdentity c m, MonadDB m) => Id Asset -> m (Maybe Asset)
lookupAsset ai = do
  ident <- peek
  dbQuery1 $(selectQuery (selectAsset 'ident) "$WHERE asset.id = ${ai}")

addAsset :: (MonadAudit c m, MonadStorage c m) => Asset -> Maybe RawFilePath -> m Asset
addAsset ba fp = do
  ident <- getAuditIdentity
  ba' <- maybe (return ba) (storeAssetFile ba) fp
  dbQuery1' $(insertAsset 'ident 'ba')

changeAsset :: (MonadAudit c m, MonadStorage c m) => Asset -> Maybe RawFilePath -> m ()
changeAsset a fp = do
  ident <- getAuditIdentity
  a2 <- maybe (return a) (storeAssetFile a) fp
  dbExecute1' $(updateAsset 'ident 'a2)

supersedeAsset :: MonadDB m => Asset -> Asset -> m ()
supersedeAsset old new =
  dbExecute1' [pgSQL|SELECT asset_supersede(${assetId old}, ${assetId new})|]

assetIsSuperseded :: MonadDB m => Asset -> m Bool
assetIsSuperseded a =
  dbExecute1 [pgSQL|SELECT ''::void FROM asset_revision WHERE orig = ${assetId a} LIMIT 1|]

assetCreation :: MonadDB m => Asset -> m (Maybe Timestamp, Maybe T.Text)
assetCreation a = maybe (Nothing, Nothing) (first Just) <$>
  dbQuery1 [pgSQL|$SELECT audit_time, name FROM audit.asset WHERE id = ${assetId a} AND audit_action = 'add' ORDER BY audit_time DESC LIMIT 1|]

assetJSON :: Asset -> JSON.Object
assetJSON Asset{..} = JSON.record assetId $ catMaybes
  [ Just $ "format" JSON..= formatId assetFormat
  , ("classification" JSON..=) <$> assetRelease
  , ("name" JSON..=) <$> assetName
  , ("duration" JSON..=) <$> assetDuration
  , ("pending" JSON..= True) <? isNothing assetSHA1
  ]
