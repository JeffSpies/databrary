{-# LANGUAGE OverloadedStrings #-}
module Databrary.Controller.Register
  ( viewRegister
  , postRegister
  , viewPasswordReset
  , postPasswordReset
  ) where

import Control.Monad (mfilter)
import qualified Data.ByteString.Builder as BSB
import Data.Monoid ((<>), mempty)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as TLE

import Databrary.Ops
import Databrary.Has (view, peek)
import Databrary.Action
import Databrary.Action.Auth
import Databrary.Service.Mail
import Databrary.Model.Permission
import Databrary.Model.Party
import Databrary.Model.Identity
import Databrary.Model.Token
import Databrary.HTTP.Form.Deform
import Databrary.HTTP.Route.PathParser
import Databrary.Controller.Form
import Databrary.Controller.Party
import Databrary.Controller.Token
import Databrary.Controller.Angular
import Databrary.View.Register

resetPasswordMail :: Either T.Text SiteAuth -> T.Text -> (Maybe TL.Text -> TL.Text) -> AuthActionM ()
resetPasswordMail (Left email) subj body =
  sendMail [Left email] subj (body Nothing)
resetPasswordMail (Right auth) subj body = do
  tok <- loginTokenId =<< createLoginToken auth True
  req <- peek
  sendMail [Right $ view auth] subj
    (body $ Just $ TLE.decodeLatin1 $ BSB.toLazyByteString $ actionURL (Just req) viewLoginToken (HTML, tok))

viewRegister :: AppRoute ()
viewRegister = action GET (pathHTML </< "user" </< "register") $ \() -> withAuth $ do
  angular
  maybeIdentity
    (blankForm htmlRegister)
    (\_ -> redirectRouteResponse [] viewParty (HTML, TargetProfile))

postRegister :: AppRoute API
postRegister = action POST (pathAPI </< "user" </< "register") $ \api -> withoutAuth $ do
  reg <- runForm (api == HTML ?> htmlRegister) $ do
    name <- "name" .:> (deformRequired =<< deform)
    prename <- "prename" .:> deformNonEmpty deform
    email <- "email" .:> emailTextForm
    affiliation <- "affiliation" .:> deformNonEmpty deform
    _ <- "agreement" .:> (deformCheck "You must consent to the user agreement." id =<< deform)
    let p = blankParty
          { partySortName = name
          , partyPreName = prename
          , partyAffiliation = affiliation
          , partyAccount = Just a
          }
        a = Account
          { accountParty = p
          , accountEmail = email
          , accountPasswd = Nothing
          }
    return a
  auth <- maybe (flip SiteAuth mempty <$> addAccount reg) return =<< lookupSiteAuthByEmail (accountEmail reg)
  resetPasswordMail (Right auth) 
    "Databrary account created"
    $ \(Just url) ->
      "Thank you for registering with Databrary. Please use this link to complete your\n\
      \registration:\n\n"
      <> url <> "\n\n\
      \By clicking the above link, you also indicate that you have read and understand\n\
      \the Databrary Access agreement, which you can download here:\n\n\
      \http://databrary.org/policies/agreement.pdf\n\n\
      \Once you've validated your e-mail, you will be able to request authorization in\n\
      \order to be granted full access to Databrary.\n"
  okResponse [] $ "Your confirmation email has been sent to '" <> accountEmail reg <> "'."

viewPasswordReset :: AppRoute ()
viewPasswordReset = action GET (pathHTML </< "user" </< "password") $ \() -> withoutAuth $ do
  angular
  blankForm htmlPasswordReset

postPasswordReset :: AppRoute API
postPasswordReset = action POST (pathAPI </< "user" </< "password") $ \api -> withoutAuth $ do
  email <- runForm (api == HTML ?> htmlPasswordReset) $ do
    "email" .:> emailTextForm
  auth <- mfilter ((PermissionADMIN >) . accessMember) <$> lookupSiteAuthByEmail email
  resetPasswordMail (maybe (Left email) Right auth)
    "Databrary password reset" $
    ("Someone (hopefully you) has requested to reset the password for the Databrary\n\
    \account associated with this email address. If you did not request this, let us\n\
    \know (by replying to this message) or simply ignore it.\n\n" <>)
    . maybe
      "Unfortunately, no Databrary account found for this email address. You can try\n\
      \again with a different email address, or reply to this email for assistance.\n"
      ("Otherwise, you may use this link to reset your Databrary password:\n\n" <>)
  okResponse [] $ "Your password reset information has been sent to '" <> email <> "'."
