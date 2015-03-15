{-# LANGUAGE OverloadedStrings #-}
module Databrary.Mail
  ( sendMail
  ) where

import Control.Monad.IO.Class (MonadIO, liftIO)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Network.Mail.Mime

import Databrary.Model.Party.Types

baseMail :: Mail
baseMail = emptyMail (Address (Just "Databrary") "help@databrary.org")

sendMail :: MonadIO m => [Either T.Text Account] -> T.Text -> [T.Text] -> m ()
sendMail to subj body =
  liftIO $ renderSendMail $ addPart [plainPart (TL.fromChunks body)] $ baseMail
    { mailTo = map addr to
    , mailHeaders = [("Subject", subj)]
    }
  where
  addr (Left e) = Address Nothing e
  addr (Right Account{ accountEmail = email, accountParty = Party{ partyName = name } }) =
    Address (Just name) email