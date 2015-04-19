{-# LANGUAGE OverloadedStrings #-}
module Databrary.Controller.Login
  ( loginAccount
  , viewLogin
  , postLogin
  , postLogout
  , viewUser
  , postUser
  ) where

import Control.Applicative ((<|>))
import Control.Monad (when, unless)
import Control.Monad.Reader (withReaderT)
import Control.Monad.Trans.Class (lift)
import qualified Crypto.BCrypt as BCrypt
import qualified Data.ByteString as BS
import qualified Data.Foldable as Fold
import Data.Maybe (fromMaybe)
import qualified Data.Text as T

import Databrary.Ops
import Databrary.Has (view, peek)
import Databrary.Action
import Databrary.Action.Auth
import Databrary.HTTP.Cookie
import Databrary.Model.Id.Types
import Databrary.Model.Party
import Databrary.Model.Identity
import Databrary.Model.Permission
import Databrary.Model.Token
import Databrary.HTTP.Form.Deform
import Databrary.Controller.Form
import Databrary.Controller.Permission
import Databrary.Controller.Angular
import Databrary.View.Login

import {-# SOURCE #-} Databrary.Controller.Root
import {-# SOURCE #-} Databrary.Controller.Party

loginAccount :: API -> SiteAuth -> Bool -> AppAction
loginAccount api auth su = do
  sess <- createSession auth su
  let Token (Id tok) ex = view sess
  cook <- setSignedCookie "session" tok ex
  case api of
    JSON -> okResponse [cook] $ identityJSON (Identified sess)
    HTML -> redirectRouteResponse [cook] $ viewParty HTML TargetProfile

viewLogin :: AppRAction
viewLogin = action GET ["user", "login" :: T.Text] $ withAuth $ do
  angular
  maybeIdentity
    (blankForm htmlLogin)
    (\_ -> redirectRouteResponse [] $ viewParty HTML TargetProfile)

checkPassword :: BS.ByteString -> Account -> Bool
checkPassword p = Fold.any (`BCrypt.validatePassword` p) . accountPasswd

postLogin :: API -> AppRAction
postLogin api = action POST (api, ["user", "login" :: T.Text]) $ withoutAuth $ do
  (Just auth, su) <- runForm (api == HTML ?> htmlLogin) $ do
    email <- "email" .:> emailTextForm
    password <- "password" .:> deform
    superuser <- "superuser" .:> deform
    auth <- lift $ lookupSiteAuthByEmail email
    let p = view <$> auth
        a = partyAccount =<< p
        su = superuser && Fold.any ((PermissionADMIN ==) . accessPermission) auth
    attempts <- lift $ maybe (return 0) recentAccountLogins p
    let pass = checkPassword password `Fold.any` a
        block = attempts > 4
    lift $ auditAccountLogin pass (fromMaybe nobodyParty p) email
    when block $ "email" .:> deformError "Too many login attempts. Try again later."
    unless pass $ "password" .:> deformError "Incorrect login."
    return (auth, su)
  withReaderT authApp $ loginAccount api auth su

postLogout :: API -> AppRAction
postLogout api = action POST (api, ["user", "logout" :: T.Text]) $ withAuth $ do
  maybeIdentity (return False) removeSession
  case api of
    JSON -> okResponse [cook] $ identityJSON UnIdentified
    HTML -> redirectRouteResponse [cook] $ viewRoot HTML
  where cook = clearCookie "session"

viewUser :: AppRAction
viewUser = action GET (JSON, "user" :: T.Text) $ withAuth $
  okResponse [] . identityJSON =<< peek

postUser :: API -> AppRAction
postUser api = action POST (api, "user" :: T.Text) $ withAuth $ do
  acct <- authAccount
  acct' <- runForm (api == HTML ?> htmlUserForm acct) $ do
    "auth" .:> do
      p <- deform
      deformGuard "Incorrect password." (checkPassword p acct)
    email <- "email" .:> deformNonEmpty deform
    passwd <- "password" .:> deformNonEmpty (passwordForm acct)
    return acct
      { accountEmail = fromMaybe (accountEmail acct) email
      , accountPasswd = passwd <|> accountPasswd acct
      }
  changeAccount acct'
  case api of
    JSON -> okResponse [] $ partyJSON $ accountParty acct'
    HTML -> redirectRouteResponse [] $ viewParty api TargetProfile
