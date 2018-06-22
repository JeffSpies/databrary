{-# LANGUAGE OverloadedStrings #-}
module Store.Service
  ( Storage
  , initStorage
  ) where

import Control.Monad (unless, foldM_, forM_)
import Data.Maybe (catMaybes)
import System.Directory (getTemporaryDirectory, createDirectoryIfMissing)
import System.IO.Error (mkIOError, doesNotExistErrorType, illegalOperationErrorType)
import System.Posix.FilePath (addTrailingPathSeparator)
import System.Posix.Files.ByteString (isDirectory, deviceID, getFileStatus)

import Ops
import qualified Store.Config as C
import Files
import Store.Types
import Store.Transcoder

initStorage :: C.Config -> IO Storage
initStorage conf
  | Just down <- conf C.! "DOWN" = return $ error $ "Storage unavailable: " ++ down
  | otherwise = do
      fp <- getTemporaryDirectory
      temp <- fromMaybeM (rawFilePath fp) $ conf C.! "temp"

      foldM_ (\dev f -> do
        s <- getFileStatus f
        f' <- unRawFilePath f
        unless (isDirectory s)
          $ ioError $ mkIOError doesNotExistErrorType "storage directory" Nothing (Just f')
        let d = deviceID s
        unless (all (d ==) dev)
          $ ioError $ mkIOError illegalOperationErrorType "storage filesystem" Nothing (Just f')
        return $ Just d)
        Nothing $ catMaybes [Just master, Just temp, Just upload, stage]

      forM_ cache $ \c -> do
        let tmp = c </> "tmp"
        tmpPath <- unRawFilePath tmp
        createDirectoryIfMissing False tmpPath

      let tempPath = addTrailingPathSeparator temp
      unTempPath <- unRawFilePath tempPath
      createDirectoryIfMissing False (getStorageTempParticipantUpload' unTempPath)

      tc <- initTranscoder (conf C.! "transcode")

      return $ Storage
        { storageMaster = master
        , storageFallback = conf C.! "fallback"
        , storageTemp = tempPath
        , storageUpload = upload
        , storageCache = cache
        , storageStage = stage
        , storageTranscoder = tc
        }
  where
  master = conf C.! "master"
  upload = conf C.! "upload"
  cache = conf C.! "cache"
  stage = conf C.! "stage"
