{-# LANGUAGE TemplateHaskell #-}
module Databrary.Action.Auth
  ( AuthRequest(..)
  , MonadAuthAction
  , AuthActionM
  , AuthAction
  , withAuth
  , withoutAuth
  , withReAuth
  ) where

import Control.Monad.Reader (withReaderT, asks)

import Databrary.Has (makeHasRec)
import Databrary.Action.Types
import Databrary.Action.App
import Databrary.Model.Identity
import Databrary.Model.Party
import Databrary.Controller.Analytics

data AuthRequest = AuthRequest
  { authApp :: !AppRequest
  , authIdentity :: !Identity
  }

makeHasRec ''AuthRequest ['authApp, 'authIdentity]

type AuthActionM a = ActionM AuthRequest a
type AuthAction = Action AuthRequest

type MonadAuthAction q m = (MonadHasAuthRequest q m, ActionData q)

instance ActionData AuthRequest where
  returnResponse s h r = asks (returnResponse s h r . authApp)

withAuth :: AuthAction -> AppAction
withAuth f = do
  i <- determineIdentity
  withReaderT (\a -> AuthRequest a i) $
    angularAnalytics >> f

withoutAuth :: AuthAction -> AppAction
withoutAuth f =
  withReaderT (\a -> AuthRequest a UnIdentified) $ angularAnalytics >> f

withReAuth :: SiteAuth -> AuthAction -> AppAction
withReAuth u =
  withReaderT (\a -> AuthRequest a (ReIdentified u))

