{-# LANGUAGE OverloadedStrings #-}
module Databrary.Routes
  ( routeMap
  ) where

import Databrary.HTTP.Route
import Databrary.Action
import Databrary.Controller.Root
import Databrary.Controller.Login
import Databrary.Controller.Register
import Databrary.Controller.Token
import Databrary.Controller.Party
import Databrary.Controller.Authorize
import Databrary.Controller.Volume
import Databrary.Controller.VolumeAccess
import Databrary.Controller.Funding
import Databrary.Controller.Container
import Databrary.Controller.Slot
import Databrary.Controller.Record
import Databrary.Controller.Citation
import Databrary.Controller.Upload
import Databrary.Controller.Format
import Databrary.Controller.Asset
import Databrary.Controller.AssetSegment
import Databrary.Controller.Excerpt
import Databrary.Controller.Zip
import Databrary.Controller.Tag
import Databrary.Controller.Comment
import Databrary.Controller.CSV
import Databrary.Controller.Audit
import Databrary.Controller.Transcode
import Databrary.Controller.Ingest
import Databrary.Controller.Web

routeMap :: RouteMap AppAction
routeMap = fromRouteList
  [ route viewRoot
  , route viewRobotsTxt

  , route viewUser
  , route postUser
  , route viewLogin
  , route postLogin
  , route postLogout
  , route viewRegister
  , route postRegister
  , route viewPasswordReset
  , route postPasswordReset
  , route viewLoginToken
  , route postPasswordToken
  , route resendInvestigator

  , route viewParty
  , route postParty
  , route viewPartyEdit
  , route viewPartyCreate
  , route viewPartyDelete
  , route viewAuthorize
  , route postAuthorize
  , route deleteAuthorize
  , route postAuthorizeNotFound
  , route viewAvatar
  , route createParty
  , route deleteParty
  , route queryParties
  , route adminParties

  , route viewVolume
  , route postVolume
  , route viewVolumeEdit
  , route viewVolumeAccess
  , route postVolumeAccess
  , route viewVolumeLinks
  , route postVolumeLinks
  , route postVolumeFunding
  , route deleteVolumeFunder
  , route viewVolumeCreate
  , route createVolume
  , route queryVolumes
  , route zipVolume
  , route thumbVolume
  , route csvVolume

  , route createContainer
  , route viewSlot
  , route viewContainerEdit
  , route postContainer
  , route deleteContainer
  , route zipContainer
  , route thumbSlot

  , route viewFormats

  , route viewAsset
  , route postAsset
  , route viewAssetEdit
  , route deleteAsset
  , route downloadAsset
  , route viewAssetCreate
  , route createAsset
  , route createSlotAsset
  , route viewSlotAssetCreate

  , route viewAssetSegment
  , route downloadAssetSegment
  , route thumbAssetSegment
  , route postExcerpt
  , route deleteExcerpt

  , route createRecord
  , route viewRecord
  , route postRecordMeasure
  , route deleteRecord
  , route postRecordSlot
  , route deleteRecordSlot

  , route queryTags
  , route postTag
  , route deleteTag
  , route viewTopTags
  , route postComment

  , route uploadStart
  , route uploadChunk
  , route testChunk
  , route viewConstants
  , route getCitation
  , route queryFunder
  , route remoteTranscode
  , route viewActivity

  , route viewTranscodes
  , route postTranscode
  , route viewIngest
  , route postIngest

  , route webFile
  ]
