{-# LANGUAGE OverloadedStrings #-}
module Store.Probe
  ( Probe(..)
  , probeLength
  , probeFile
  , probeAutoPosition
  , avProbeCheckFormat
  ) where

import Control.Arrow (left)
import Control.Exception (try)
import Control.Monad.IO.Class (MonadIO(..))
import Control.Monad.Trans.Except (ExceptT(..), runExceptT, throwE)
import qualified Data.ByteString as BS
import Data.List (isPrefixOf)
import Data.Monoid ((<>))
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time.Calendar (diffDays)
import Data.Time.LocalTime (ZonedTime(..), LocalTime(..), timeOfDayToTime)
import System.Posix.FilePath (takeExtension)

import Has
import Files
import Service.DB
import Model.Format
import Model.Offset
import Model.Container.Types
import Model.AssetSlot
import Store.AV
-- import Action.Types

data Probe
  = ProbePlain
    { probeFormat :: Format }
  | ProbeAV
    { probeFormat :: Format
    , probeTranscode :: Format
    , probeAV :: AVProbe
    }

-- | Get detected length if this is an audio or video file
probeLength :: Probe -> Maybe Offset
probeLength ProbeAV{ probeAV = av } = avProbeLength av
probeLength _ = Nothing

-- | Detect whether the mimetype expected in the file given is accepted by Databrary,
-- and probe/wrap the file into a Probe describing it conversion target and current format.
probeFile :: (MonadIO m, MonadHas AV c m) => BS.ByteString -> RawFilePath -> m (Either T.Text Probe)
probeFile n f = runExceptT $ maybe
  (throwE $ "unknown or unsupported format: " <> TE.decodeLatin1 (takeExtension n))
  (\fmt -> case formatTranscodable fmt of
    Nothing -> return $ ProbePlain fmt
    Just t
      | t == videoFormat || t == audioFormat -> do
        av <- ExceptT $ left (("could not process unsupported or corrupt media file: " <>) . T.pack . avErrorString)
          <$> focusIO (try . avProbe f)
        if avProbeHas AVMediaTypeVideo av
          then return $ ProbeAV fmt videoFormat av
          else if avProbeHas AVMediaTypeAudio av
            then return $ ProbeAV fmt audioFormat av
            else throwE "no supported video or audio content found"
      | otherwise -> fail "unhandled format conversion")
  $ getFormatByFilename n

-- TODO: make this pure
probeAutoPosition :: MonadDB c m => Container -> Maybe Probe -> m Offset
probeAutoPosition
    Container{ containerRow = ContainerRow { containerDate = Just d } }
    (Just ProbeAV{ probeAV = AVProbe{ avProbeDate = Just (ZonedTime (LocalTime d' t) _) } })
  | dd >= -1 && dd <= 1 && dt >= negate day2 && dt <= 3*day2 =
    return $ diffTimeOffset dt
  where
    dd = diffDays d' d
    dt = fromInteger dd*day + timeOfDayToTime t
    day2 = 43200
    day = 2*day2
probeAutoPosition c _ = findAssetContainerEnd c

-- |Test if this represents a file in standard format.
avProbeCheckFormat :: Format -> AVProbe -> Bool
avProbeCheckFormat fmt AVProbe{ avProbeFormat = "mov,mp4,m4a,3gp,3g2,mj2", avProbeStreams = ((AVMediaTypeVideo,"h264"):s) }
  -- Note: isPrefixOf use here is terse/counterinteruitive. should explicitly test for empty list
  | fmt == videoFormat = s `isPrefixOf` [(AVMediaTypeAudio,"aac")]
avProbeCheckFormat fmt AVProbe{ avProbeFormat = "mp3", avProbeStreams = ((AVMediaTypeAudio,"mp3"):_) }
  | fmt == audioFormat = True
avProbeCheckFormat _ _ = False

