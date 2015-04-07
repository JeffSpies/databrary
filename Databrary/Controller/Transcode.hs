{-# LANGUAGE OverloadedStrings #-}
module Databrary.Controller.Transcode
  ( remoteTranscode
  ) where

import Control.Applicative (optional)
import Control.Monad (liftM3)
import Data.Bits (shiftL, (.|.))
import qualified Data.ByteString as BS
import Data.Char (isHexDigit, digitToInt)
import Data.Word (Word8)

import Databrary.Ops
import Databrary.Crypto
import Databrary.Web.Form.Deform
import Databrary.Action
import Databrary.Action.Auth
import Databrary.Model.Id
import Databrary.Model.Transcode
import Databrary.Store.Transcode
import Databrary.Controller.Form

unHex :: String -> Maybe [Word8]
unHex [] = Just []
unHex [_] = Nothing
unHex (h:l:r) = do
  hb <- unhex h
  lb <- unhex l
  ((shiftL hb 4 .|. lb) :) <$> unHex r
  where unhex x = isHexDigit x ?> fromIntegral (digitToInt x)

sha1Form :: (Functor m, Monad m) => DeformT m BS.ByteString
sha1Form = do
  b <- deform
  deformGuard "Invalid SHA1 hex string" (length b == 40)
  maybe (deformError "Invalid hex string" >> return BS.empty) (return . BS.pack) $ unHex b

remoteTranscode :: Id Transcode -> AppRAction
remoteTranscode ti = action POST (JSON, ti) $ do
  t <- maybeAction =<< lookupTranscode ti
  withReAuth (transcodeOwner t) $ do
    auth <- transcodeAuth t
    (res, sha1, logs) <- runForm Nothing $ do
      "auth" .:> (deformCheck "Invalid authentication" (constEqBytes auth) =<< deform)
      "pid" .:> (deformCheck "PID mismatch" (transcodeProcess t ==) =<< deformNonEmpty deform)
      liftM3 (,,)
        ("res" .:> deform)
        ("sha1" .:> optional sha1Form)
        ("log" .:> deform)
    collectTranscode t res sha1 logs
    okResponse [] BS.empty
