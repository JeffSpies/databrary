{-# LANGUAGE OverloadedStrings #-}
module Databrary.View.Register
  ( htmlRegister
  , htmlPasswordReset
  ) where

import Databrary.Action
import Databrary.View.Form

import {-# SOURCE #-} Databrary.Controller.Register

htmlRegister :: AuthRequest -> FormHtml
htmlRegister req = htmlForm "Register" (postRegister HTML) req $ do
  field "name" $ inputText (Nothing :: Maybe String)
  field "email" $ inputText (Nothing :: Maybe String)
  field "affiliation" $ inputText (Nothing :: Maybe String)
  field "agreement" $ inputCheckbox False

htmlPasswordReset :: AuthRequest -> FormHtml
htmlPasswordReset req = htmlForm "Password Reset" (postPasswordReset HTML) req $ do
  field "email" $ inputText (Nothing :: Maybe String)
