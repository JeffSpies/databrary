module Databrary.Store
  ( RawFilePath
  , rawFilePath
  , unRawFilePath
  , sameFile
  , hashFile
  ) where

import Crypto.Hash (HashAlgorithm, hashInit, hashUpdate, hashFinalize, Digest)
import qualified Data.ByteString as BS
import Data.ByteString.Lazy.Internal (defaultChunkSize)
import qualified GHC.Foreign as GHC
import GHC.IO.Encoding (getFileSystemEncoding)
import System.IO (withFile, IOMode(ReadMode))
import System.Posix.FilePath (RawFilePath)
import System.Posix.Files.ByteString (getFileStatus, deviceID, fileID)
import System.IO.Unsafe (unsafeDupablePerformIO)

rawFilePath :: FilePath -> RawFilePath
rawFilePath s = unsafeDupablePerformIO $ do
  enc <- getFileSystemEncoding
  GHC.withCStringLen enc s BS.packCStringLen

unRawFilePath :: RawFilePath -> FilePath
unRawFilePath b = unsafeDupablePerformIO $ do
  enc <- getFileSystemEncoding
  BS.useAsCStringLen b $ GHC.peekCStringLen enc

sameFile :: RawFilePath -> RawFilePath -> IO Bool
sameFile f1 f2 = do
  s1 <- getFileStatus f1
  s2 <- getFileStatus f2
  if deviceID s1 == deviceID s2 && fileID s1 == fileID s2
    then return True
    else withFile (unRawFilePath f1) ReadMode $ \h1 -> withFile (unRawFilePath f2) ReadMode $ cmp h1 where
  cmp h1 h2 = do
    b1 <- BS.hGet h1 defaultChunkSize
    b2 <- BS.hGet h2 defaultChunkSize
    if b1 == b2
      then if BS.null b1 then return True else cmp h1 h2
      else return False

hashFile :: HashAlgorithm a => RawFilePath -> IO (Digest a)
hashFile f = withFile (unRawFilePath f) ReadMode $ run hashInit where
  run s h = do
    b <- BS.hGetSome h defaultChunkSize
    if BS.null b
      then return $! hashFinalize s
      else (run $! hashUpdate s b) h

