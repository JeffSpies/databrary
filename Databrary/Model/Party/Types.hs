{-# LANGUAGE OverloadedStrings, TemplateHaskell, TypeFamilies #-}
module Databrary.Model.Party.Types 
  ( Party(..)
  , MonadHasParty
  , Account(..)
  , MonadHasAccount
  , SiteAuth(..)
  , MonadHasSiteAuth
  , nobodySiteAuth
  , blankParty
  ) where

import qualified Data.ByteString as BS
import Data.Monoid (mempty)
import qualified Data.Text as T
import Instances.TH.Lift ()
import Language.Haskell.TH.Lift (deriveLiftMany)

import Databrary.Has (makeHasRec, Has(..))
import Databrary.Model.URL (URI)
import Databrary.Model.Kind
import Databrary.Model.Id.Types
import Databrary.Model.Permission.Types

type instance IdType Party = Int32

data Party = Party
  { partyId :: Id Party
  , partySortName :: T.Text
  , partyPreName :: Maybe T.Text
  , partyAffiliation :: Maybe T.Text
  , partyURL :: Maybe URI
  , partyAccount :: Maybe Account
  , partyPermission :: Permission
  , partyAccess :: Maybe Access
  }

data Account = Account
  { accountEmail :: T.Text
  , accountPasswd :: Maybe BS.ByteString
  , accountParty :: Party
  }

makeHasRec ''Party ['partyId]
makeHasRec ''Account ['accountParty]

instance Has Access Party where
  view Party{ partyAccess = Just a } = a
  view _ = mempty
instance Has Permission Party where
  view Party{ partyPermission = p, partyAccess = Just a } = p `max` accessPermission' a
  view Party{ partyPermission = p } = p

instance Kinded Party where
  kindOf _ = "party"

-- Access to the site by a (current) account
data SiteAuth = SiteAuth
  { siteAccount :: Account -- maybe should be Party (for nobody)
  , siteAccess :: Access
  }

makeHasRec ''SiteAuth ['siteAccount, 'siteAccess]

deriveLiftMany [''Party, ''Account]

-- this is unfortunate, mainly to avoid untangling Party.SQL
nobodySiteAuth :: SiteAuth
nobodySiteAuth = SiteAuth
  { siteAccount = Account
    { accountEmail = "nobody@databrary.org"
    , accountPasswd = Nothing
    , accountParty = Party
      { partyId = Id (-1)
      , partySortName = "Nobody"
      , partyPreName = Nothing
      , partyAffiliation = Nothing
      , partyURL = Nothing
      , partyAccount = Nothing
      , partyPermission = PermissionREAD
      , partyAccess = Just minBound
      }
    }
  , siteAccess = mempty
  }

blankParty :: Party
blankParty = Party
  { partyId = error "blankParty"
  , partySortName = ""
  , partyPreName = Nothing
  , partyAffiliation = Nothing
  , partyURL = Nothing
  , partyAccount = Nothing
  , partyPermission = PermissionNONE
  , partyAccess = Nothing
  }
