{-# LANGUAGE OverloadedStrings #-}
module Databrary.Web.Routes
  ( generateRoutesJS
  , jsRoute
  ) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Builder as B
import Data.Monoid ((<>))
import System.IO (withBinaryFile, IOMode(WriteMode), hPutStr, hPutStrLn)

import Databrary.JSON (quoteByteString)
import Databrary.HTTP.Path.JS
import Databrary.HTTP.Route
import Databrary.Web
import Databrary.Web.Files

import {-# SOURCE #-} Databrary.Routes

jsRoute :: BS.ByteString -> Route r a -> a -> B.Builder
jsRoute n r v = B.char7 '\n' <> quoteByteString '"' n
  <> B.string7 ":{method:" <> quoteByteString '"' (routeMethod r)
  <> B.string7 ",route:" <> jsPath (routePath r) v <> B.string7 "},"

generateRoutesJS :: WebGenerator
generateRoutesJS f = staticWebGenerate f $
  withBinaryFile (webFileAbs f) WriteMode $ \h -> do
    hPutStr h "app.constant('routeData',{"
    B.hPutBuilder h jsRoutes
    hPutStrLn h "});"
