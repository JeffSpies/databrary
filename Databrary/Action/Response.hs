{-# LANGUAGE TypeSynonymInstances, DeriveDataTypeable, OverloadedStrings #-}
module Databrary.Action.Response
  ( Response
  , ResponseData(..)
  , result
  , runResult
  ) where

import Control.Exception (Exception, throwIO, handle)
import Control.Monad.IO.Class (MonadIO, liftIO)
import qualified Data.Aeson as JSON
import qualified Data.ByteString as BS
import qualified Data.ByteString.Builder as BSB
import qualified Data.ByteString.Lazy as BSL
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as TLE
import Data.Typeable (Typeable)
import Network.HTTP.Types (ResponseHeaders, Status, hContentType)
import Network.Wai (Response, responseBuilder, responseLBS, StreamingBody, responseStream, FilePart(..), responseFile, responseStatus)
import qualified Text.Blaze.Html as Html
import qualified Text.Blaze.Html.Renderer.Utf8 as Html

class ResponseData r where
  response :: Status -> ResponseHeaders -> r -> Response

instance ResponseData (Status -> ResponseHeaders -> Response) where
  response s h r = r s h

instance ResponseData BSB.Builder where
  response = responseBuilder

instance ResponseData BSL.ByteString where
  response = responseLBS

instance ResponseData BS.ByteString where
  response s h = responseBuilder s h . BSB.byteString

instance ResponseData StreamingBody where
  response = responseStream

instance ResponseData FilePath where
  response s h f = responseFile s h f Nothing

instance ResponseData (FilePath, FilePart) where
  response s h (f, p) = responseFile s h f (Just p)

instance ResponseData (FilePath, Maybe FilePart) where
  response s h (f, p) = responseFile s h f p

instance ResponseData T.Text where
  response s h =
    response s ((hContentType, "text/plain;charset=utf-8") : h) . TE.encodeUtf8Builder

instance ResponseData TL.Text where
  response s h =
    response s ((hContentType, "text/plain;charset=utf-8") : h) . TLE.encodeUtf8Builder

instance ResponseData JSON.Value where
  response s h =
    response s ((hContentType, "text/json;charset=utf-8") : h) . JSON.encode

instance ResponseData JSON.Object where
  response s h = response s h . JSON.Object

instance ResponseData Html.Html where
  response s h =
    response s ((hContentType, "text/html;charset=utf-8") : h) . Html.renderHtmlBuilder

newtype Result = Result { resultResponse :: Response } deriving (Typeable)
instance Show Result where
  showsPrec p (Result r) = showParen (p > 10)
    $ showString "Result " . showsPrec 11 (responseStatus r)
instance Exception Result

result :: MonadIO m => Response -> m a
result = liftIO . throwIO . Result

runResult :: IO Response -> IO Response
runResult = handle (return . resultResponse)
