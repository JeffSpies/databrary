{-# LANGUAGE OverloadedStrings, TemplateHaskell, RecordWildCards #-}
{-# OPTIONS_GHC -ddump-splices #-}
module Databrary.Service.Types
  ( Secret(..)
  , Service(..)
  , MonadHasService
  ) where

import qualified Data.ByteString as BS

import Databrary.Has (makeHasRec)
import Databrary.Service.DB (DBConn)
import Databrary.Service.Entropy (Entropy)
import Databrary.HTTP.Client (HTTPClient)
import Databrary.Store.Types (Storage)
import Databrary.Service.Passwd (Passwd)
import Databrary.Service.Log (Logs)
import Databrary.Service.Messages (Messages)
import Databrary.Web.Types (Web)
import Databrary.Store.AV (AV)
import Databrary.Model.Time

newtype Secret = Secret BS.ByteString

data Service = Service
  { serviceStartTime :: !Timestamp
  , serviceSecret :: !Secret
  , serviceEntropy :: !Entropy
  , servicePasswd :: !Passwd
  , serviceLogs :: !Logs
  , serviceMessages :: !Messages
  , serviceDB :: !DBConn
  , serviceStorage :: !Storage
  , serviceWeb :: !Web
  , serviceHTTPClient :: !HTTPClient
  , serviceAV :: !AV
  }

makeHasRec ''Service ['serviceDB, 'serviceMessages, 'serviceEntropy, 'serviceSecret, 'serviceHTTPClient, 'serviceStorage, 'serviceWeb, 'servicePasswd, 'serviceAV]
