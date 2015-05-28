{-# LANGUAGE OverloadedStrings, ViewPatterns #-}
module Databrary.Controller.Zip
  ( zipContainer
  , zipVolume
  ) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Builder as BSB
import qualified Data.ByteString.Char8 as BSC
import qualified Data.ByteString.Lazy as BSL
import Data.Monoid ((<>))
import qualified Data.Text.Encoding as TE
import qualified Data.Traversable as Trav
import Network.HTTP.Types (hContentType, hCacheControl)
import System.Posix.FilePath ((<.>))

import Databrary.Ops
import Databrary.Has (peek)
import Databrary.Store.Asset
import Databrary.Store.Filename
import Databrary.Store.Zip
import Databrary.Model.Id
import Databrary.Model.Permission
import Databrary.Model.Volume
import Databrary.Model.Container
import Databrary.Model.Slot
import Databrary.Model.Asset
import Databrary.Model.AssetSlot
import Databrary.Model.Format
import Databrary.Model.Party
import Databrary.HTTP
import Databrary.HTTP.Path.Parser
import Databrary.Action
import Databrary.Controller.Paths
import Databrary.Controller.Asset
import Databrary.Controller.Container
import Databrary.Controller.Volume
import Databrary.Controller.Party

assetZipEntry :: AssetSlot -> AuthActionM (Maybe ZipEntry)
assetZipEntry (dataPermission -> PermissionNONE) = return Nothing
assetZipEntry AssetSlot{ slotAsset = a } = getAssetFile a >>= Trav.mapM (\f -> do
  req <- peek
  -- (t, _) <- assetCreation a
  -- Just (t, s) <- fileInfo f
  return ZipEntry
    { zipEntryName = makeFilename (assetDownloadName a) `addFormatExtension` assetFormat a
    , zipEntryTime = Nothing
    , zipEntryCRC32 = Nothing
    , zipEntrySize = fromIntegral <$> assetSize a
    , zipEntryComment = BSL.toStrict $ BSB.toLazyByteString $ actionURL (Just req) viewAsset (HTML, assetId a) []
    , zipEntryContent = ZipEntryFile f
    })

containerZipEntry :: Container -> AuthActionM ZipEntry
containerZipEntry c = do
  req <- peek
  a <- mapMaybeM assetZipEntry =<< lookupContainerAssets c
  return ZipEntry
    { zipEntryName = makeFilename (containerDownloadName c)
    , zipEntryTime = Nothing
    , zipEntryCRC32 = Nothing
    , zipEntrySize = Nothing
    , zipEntryComment = BSL.toStrict $ BSB.toLazyByteString $ actionURL (Just req) viewContainer (HTML, containerId c) []
    , zipEntryContent = ZipDirectory a
    }

volumeZipEntry :: Volume -> AuthActionM ZipEntry
volumeZipEntry v = do
  req <- peek
  c <- mapM containerZipEntry =<< lookupVolumeContainers v
  n <- volumeDownloadName v
  return ZipEntry
    { zipEntryName = makeFilename n
    , zipEntryTime = Nothing
    , zipEntryCRC32 = Nothing
    , zipEntrySize = Nothing
    , zipEntryComment = BSL.toStrict $ BSB.toLazyByteString $ actionURL (Just req) viewVolume (HTML, volumeId v) []
    , zipEntryContent = ZipDirectory c
    }

zipResponse :: BS.ByteString -> [ZipEntry] -> AuthAction
zipResponse n z = do
  req <- peek
  u <- peek
  okResponse 
    [ (hContentType, "application/zip")
    , ("content-disposition", "attachment; filename=" <> quoteHTTP (n <.> "zip"))
    , (hCacheControl, "max-age=31556926, private")
    ] (streamZip z $ BSL.toStrict $ BSB.toLazyByteString
      $ BSB.string7 "Downloaded by " <> TE.encodeUtf8Builder (partyName u) <> BSB.string7 " <" <> actionURL (Just req) viewParty (HTML, TargetParty $ partyId u) [] <> BSB.char7 '>')

zipEmpty :: ZipEntry -> Bool
zipEmpty ZipEntry{ zipEntryContent = ZipDirectory l } = any zipEmpty l
zipEmpty _ = True

zipContainer :: AppRoute (Id Slot)
zipContainer = action GET (pathSlotId </< "zip") $ \ci -> withAuth $ do
  c <- getContainer PermissionPUBLIC ci
  z <- containerZipEntry c
  auditSlotDownload (not $ zipEmpty z) (containerSlot c)
  zipResponse ("databrary-" <> BSC.pack (show (volumeId (containerVolume c))) <> "-" <> BSC.pack (show (containerId c))) [z]

zipVolume :: AppRoute (Id Volume)
zipVolume = action GET (pathId </< "zip") $ \vi -> withAuth $ do
  v <- getVolume PermissionPUBLIC vi
  z <- volumeZipEntry v
  auditVolumeDownload (not $ zipEmpty z) v
  zipResponse ("databrary-" <> BSC.pack (show (volumeId v))) [z]
