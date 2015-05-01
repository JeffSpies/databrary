{-# LANGUAGE OverloadedStrings #-}
module Databrary.View.Form
  ( FormHtml
  , field
  , inputText
  , inputTextarea
  , inputPassword
  , inputCheckbox
  , inputSelect
  , inputEnum
  , inputDate
  , inputFile
  , inputHidden
  , htmlForm
  ) where

import Control.Applicative ((<|>))
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Control (liftWith)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import qualified Data.Foldable as Fold
import Data.Maybe (fromMaybe)
import Data.Monoid (mempty)
import qualified Data.Text as T
import Data.Time.Format (formatTime)
import qualified Text.Blaze.Internal as M
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as HA
import System.Locale (defaultTimeLocale)

import Databrary.Ops
import Databrary.Has (peek, peeks)
import Databrary.Model.Enum
import Databrary.Model.Time
import Databrary.Action
import Databrary.HTTP.Form
import Databrary.HTTP.Form.Errors
import Databrary.HTTP.Form.View
import Databrary.View.Html
import Databrary.View.Template

type FormHtmlM = FormViewT M.MarkupM
type FormHtml = FormHtmlM ()

liftFormHtml :: (M.MarkupM FormErrors -> H.Html) -> FormHtml -> FormHtml
liftFormHtml h f = liftWith $ \run -> h (snd <$> run f)

pathId :: FormHtmlM H.AttributeValue
pathId = peeks byteStringValue

value :: FormHtmlM (Maybe BS.ByteString)
value = do
  val <- peek
  return $ case val of
    FormDatumNone -> Nothing
    FormDatumJSON _ -> Nothing -- that's weird
    FormDatumBS b -> BS.null b ?!> b

errorList :: [FormErrorMessage] -> H.Html
errorList [] = mempty
errorList err =
  H.ul H.! HA.class_ "error-list" $ mapM_
    ((H.li H.! HA.class_ "error") . H.toHtml) err

errorLists :: [(FormPath, FormErrorMessage)] -> H.Html
errorLists [] = mempty
errorLists err =
  H.dl H.! HA.class_ "error-list" $ mapM_ (\(p,e) -> do
    H.dt $ H.toHtml (formPathText p)
    H.dd H.! HA.class_ "error" $ H.toHtml e) err

_label :: H.AttributeValue -> H.Html -> H.Html
_label ref = H.label
  H.! HA.for ref

type Field = H.AttributeValue -> Maybe BS.ByteString -> H.Html

field :: T.Text -> Field -> FormHtml
field k sub = k .:> do
  ref <- pathId
  err <- formViewErrors
  val <- value
  lift $ H.label $ do
    H.toHtml k
    sub ref val
    errorList err
    H.br

inputText :: H.ToValue a => Maybe a -> Field
inputText val ref dat = H.input
  H.! HA.type_ "text"
  H.! HA.id    ref
  H.! HA.name  ref
  !? (HA.value <$> (fmap byteStringValue dat <|> fmap H.toValue val))

inputTextarea :: H.ToMarkup a => Maybe a -> Field
inputTextarea val ref dat = H.textarea
  H.! HA.id    ref
  H.! HA.name  ref
  $ fromMaybe mempty $ fmap byteStringHtml dat <|> fmap H.toHtml val

inputPassword :: Field
inputPassword ref _ = H.input
  H.! HA.type_ "password"
  H.! HA.id    ref
  H.! HA.name  ref

inputCheckbox :: Bool -> Field
inputCheckbox val ref dat = H.input
  H.! HA.type_ "checkbox"
  H.! HA.id    ref
  H.! HA.name  ref
  H.!? (maybe val (const True) dat, HA.checked "checked")

inputSelect :: H.ToMarkup b => Maybe BS.ByteString -> [(BS.ByteString, b)] -> Field
inputSelect val choices ref dat = H.select
  H.! HA.id   ref
  H.! HA.name ref
  $ mapM_ (\(v, c) -> H.option
    H.!  HA.value (byteStringValue v)
    H.!? (Fold.any (v ==) (dat <|> val), HA.selected "selected")
    $ H.toHtml c) choices

inputEnum :: forall a . DBEnum a => Maybe a -> Field
inputEnum val =
  inputSelect (bshow <$> val) $ map (\(x, v) -> (bshow (x :: a), v)) pgEnumValues
  where bshow = BSC.pack . show . fromEnum

inputDate :: Maybe Date -> Field
inputDate val ref dat = H.input
  H.! HA.type_ "date"
  H.! HA.id    ref
  H.! HA.name  ref
  !? (HA.value <$> (fmap byteStringValue dat <|> fmap (H.toValue . formatTime defaultTimeLocale "%F") val))

inputFile :: Field
inputFile ref _ = H.input
  H.! HA.type_ "file"
  H.! HA.id    ref
  H.! HA.name  ref

inputHidden :: H.ToValue a => a -> Field
inputHidden val ref dat = H.input
  H.! HA.type_ "hidden"
  H.! HA.id    ref
  H.! HA.name  ref
  H.! HA.value (maybe (H.toValue val) byteStringValue dat)

htmlForm :: T.Text -> AppRoute a -> a -> AuthRequest -> FormHtml -> FormHtml
htmlForm title act arg req = liftFormHtml $ \form ->
  htmlTemplate req (Just title) $
    actionForm act arg $ do
      err <- form
      errorLists $ allFormErrors err
      H.input
        H.! HA.type_ "submit"
