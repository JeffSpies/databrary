{-# LANGUAGE TemplateHaskell #-}
module Databrary.Model.Transcode.SQL
  ( selectTranscode
  ) where

import qualified Data.ByteString as BS
import Data.Int (Int32)
import Data.Maybe (fromMaybe)
import qualified Data.Text as T

import Databrary.Model.SQL.Select
import Databrary.Model.Permission.Types
import Databrary.Model.Party.Types
import Databrary.Model.Party.SQL
import Databrary.Model.Volume.Types
import Databrary.Model.Volume.SQL
import Databrary.Model.Asset.Types
import Databrary.Model.Asset.SQL
import Databrary.Model.Segment
import Databrary.Model.Transcode.Types

makeTranscode :: Segment -> [Maybe BS.ByteString] -> Maybe Int32 -> Maybe T.Text -> SiteAuth -> (Volume -> Asset) -> (Volume -> Asset) -> (Permission -> Volume) -> Transcode
makeTranscode s f p l u a o vp =
  Transcode (a v) (siteAccount u) (o v) s (map (fromMaybe (error "NULL transcode options")) f) p l
  where v = vp PermissionADMIN

selectTranscode :: Selector -- ^ @'Transcode'@
selectTranscode = selectJoin 'id
  [ selectColumns 'makeTranscode "transcode" ["segment", "options", "process", "log"]
  , joinOn "transcode.owner = party.id"
    selectSiteAuth
  , joinOn "transcode.asset = asset.id"
    selectVolumeAsset
  , joinOn "transcode.orig = orig.id"
    $ fromMap (++ " AS orig") selectVolumeAsset
  , joinOn "asset.volume = volume.id AND orig.volume = volume.id"
    volumeRow
  ]
