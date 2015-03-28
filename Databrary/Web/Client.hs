{-# LANGUAGE OverloadedStrings #-}
module Databrary.Web.Client
  ( HTTPClient
  , initHTTPClient
  , HTTPClientM
  , httpRequest
  , httpRequestJSON
  ) where

import Control.Applicative ((<$>))
import Control.Exception (handle)
import Control.Monad.IO.Class (MonadIO, liftIO)
import qualified Data.Aeson as JSON
import qualified Data.Attoparsec.ByteString as P
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import qualified Network.HTTP.Client as HC
import Network.HTTP.Types (hAccept, hContentType, ok200)

import Databrary.Has (MonadHas, peek)

type HTTPClient = HC.Manager

initHTTPClient :: IO HTTPClient
initHTTPClient = HC.newManager HC.defaultManagerSettings
  { HC.managerConnCount = 2
  , HC.managerIdleConnectionCount = 4
  }

type HTTPClientM c m = (MonadHas HTTPClient c m, MonadIO m)

contentType :: BS.ByteString -> BS.ByteString
contentType = BSC.takeWhile (';' /=)

responseContentType :: HC.Response a -> Maybe BS.ByteString
responseContentType = fmap contentType . lookup hContentType . HC.responseHeaders

httpRequest :: HTTPClientM c m => HC.Request -> BS.ByteString -> (HC.BodyReader -> IO (Maybe a)) -> m (Maybe a)
httpRequest req acc f = do
  hcm <- peek
  liftIO $ handle (\(_ :: HC.HttpException) -> return Nothing) $
    HC.withResponse req { HC.requestHeaders = (hAccept, acc) : HC.requestHeaders req } hcm $ \res ->
      if HC.responseStatus res == ok200 && responseContentType res == Just (contentType acc)
        then f $ HC.responseBody res
        else return Nothing

httpRequestJSON :: HTTPClientM c m => HC.Request -> m (Maybe JSON.Value)
httpRequestJSON req = httpRequest req "application/json" $ \rb ->
  P.maybeResult <$> P.parseWith rb JSON.json BS.empty

