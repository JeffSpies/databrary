{-# LANGUAGE OverloadedStrings #-}
module Databrary.View.Party
  ( htmlPartyForm
  , htmlPartySearchForm
  ) where

import Data.Maybe (fromMaybe)
import Data.Monoid ((<>))

import Databrary.Ops
import Databrary.Action.Auth
import Databrary.Action
import Databrary.Model.Party
import Databrary.Controller.Paths
import Databrary.View.Form

import {-# SOURCE #-} Databrary.Controller.Party

htmlPartyForm :: Maybe Party -> AuthRequest -> FormHtml
htmlPartyForm t req = f req $ do
  field "prename" $ inputText $ partyPreName =<< t
  field "name" $ inputText $ partySortName <$> t
  field "affiliation" $ inputText $ partyAffiliation =<< t
  field "url" $ inputText $ show <$> (partyURL =<< t)
  where
  f = maybe
    (htmlForm "Create party" createParty HTML)
    (\p -> htmlForm
      ("Edit " <> partyName p)
      postParty (HTML, TargetParty (partyId p)))
    t

htmlPartySearchForm :: PartyFilter -> AuthRequest -> FormHtml
htmlPartySearchForm pf req = htmlForm "Search users" queryParties HTML req $ do
  field "query" $ inputText $ partyFilterQuery pf
  field "access" $ inputEnum $ partyFilterAccess pf
  field "institution" $ inputCheckbox $ fromMaybe False $ partyFilterInstitution pf
