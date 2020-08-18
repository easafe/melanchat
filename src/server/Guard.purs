module Server.Guard where

import Prelude
import Server.Types
import Shared.Types

import Data.Either (Either(..))
import Data.Either (Either)
import Data.Map as DM
import Data.Maybe (Maybe(..))
import Data.Maybe as DMB
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Node.HTTP (Request)
import Node.HTTP as NH
import Payload.ContentType (json)
import Payload.Headers (empty)
import Payload.Headers as PH
import Payload.ResponseTypes (Empty(..), Response)
import Payload.Server.Guards as PSG
import Payload.Server.Response as PRS
import Payload.Server.Response as PSR
import Server.Token as ST
import Shared.Cookies (cookieName)
import Shared.Router as SR

guards :: Configuration -> _
guards configuration = {
      loggedUserID: checkLoggedUser configuration,
      checkAnonymous: checkAnonymous configuration
}

checkLoggedUser :: Configuration -> Request -> Aff (Either (Response Empty) PrimaryKey)
checkLoggedUser { development, tokenSecret } request = do
      headers <- PSG.headers request
      if NH.requestMethod request == "POST" && (not development && PH.lookup "origin" headers /= Just "https://melan.chat/" || PH.lookup "content-type" headers /= Just json) then
            badRequest
       else do
            cookies <- PSG.cookies request
            maybeUserID <- liftEffect $ ST.userIDFromToken tokenSecret <<< DMB.fromMaybe "" $ DM.lookup cookieName cookies
            case maybeUserID of
                  Just userID -> pure $ Right userID
                  _ -> redirectLogin
      where redirectLogin = redirect $ Login { next: Just $ NH.requestURL request }

checkAnonymous :: Configuration -> Request -> Aff (Either (Response Empty) Unit)
checkAnonymous { development, tokenSecret } request = do
      headers <- PSG.headers request
      if NH.requestMethod request == "POST" && (not development && PH.lookup "origin" headers /= Just "https://melan.chat/" || PH.lookup "content-type" headers /= Just json) then
            badRequest
       else do
            cookies <- PSG.cookies request
            maybeUserID <- liftEffect $ ST.userIDFromToken tokenSecret <<< DMB.fromMaybe "" $ DM.lookup cookieName cookies
            case maybeUserID of
                  Just userID -> redirectIM
                  _ -> pure $ Right unit
      where redirectIM = redirect $ IM

badRequest :: forall r. Aff (Either (Response Empty) r)
badRequest = pure <<< Left $ PSR.badRequest Empty

redirect :: forall r. Route -> Aff (Either (Response Empty) r)
redirect route = pure <<< Left <<< PSR.setHeaders location $ PRS.found Empty
      where location = PH.set "Location" (SR.fromRoute route) empty