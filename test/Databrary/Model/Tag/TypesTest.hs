{-# LANGUAGE OverloadedStrings, ScopedTypeVariables #-}
module Databrary.Model.Tag.TypesTest where

import Test.Tasty.HUnit

import Databrary.Model.Tag.Types
import Databrary.Model.TypeOrphans ()

unit_validateTag :: Assertion
unit_validateTag =
  -- example
  -- typical
  -- edge cases
  validateTag "efg123" @?= Nothing
