-- | This module takes care of websocket plus chat editor events.
module Client.IM.Chat(
        update,
        startChat,
        sendMessage,
        receiveMessage
) where

import Client.Common.Types
import Debug.Trace
import Prelude
import Shared.IM.Types
import Shared.Types

import Client.Common.DOM as CCD
import Client.IM.Contacts as CICN
import Client.IM.Flame (NextMessage, NoMessages, MoreMessages)
import Client.IM.Flame as CIF
import Client.IM.WebSocket as CIW
import Data.Array ((:), (!!))
import Data.Array as DA
import Data.Either (Either(..))
import Data.Either as DET
import Data.Maybe (Maybe(..))
import Data.Maybe as DM
import Data.Newtype (class Newtype)
import Data.Newtype as DN
import Data.Tuple (Tuple(..), (:>))
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Console as EC
import Effect.Now as EN
import Flame (ListUpdate)
import Flame as F
import Shared.Newtype as SN
import Shared.PrimaryKey as SP
import Shared.Unsafe ((!@))
import Shared.Unsafe as SU

update :: IMModel -> ChatMessage -> MoreMessages
update model =
        case _ of
                BeforeSendMessage content -> startChat model content
                SendMessage content -> do
                        sendMessage model
                ReceiveMessage payload -> do
                        isFocused <- liftEffect CCD.documentHasFocus
                        receiveMessage isFocused model payload

startChat :: IMModel -> String -> NextMessage IMMessage
startChat model@(IMModel {
        chatting,
        user: IMUser { id },
        contacts,
        suggesting,
        suggestions
}) content =
        snocContact :> [nextSendMessage]
        where   snocContact =
                        case Tuple chatting suggesting of
                                Tuple Nothing (Just index) ->
                                        let chatted =  suggestions !@ index
                                        in SN.updateModel model $ _ {
                                                chatting = Just 0,
                                                suggesting = Nothing,
                                                contacts = DA.cons (Contact { user: chatted, chatStarter: id, history: [] }) contacts,
                                                suggestions = SU.unsafeFromJust "startChat" $ DA.deleteAt index suggestions
                                        }
                                _ ->  model
                nextSendMessage = do
                        date <- liftEffect $ map MDateTime EN.nowDateTime
                        CIF.next <<< CM $ SendMessage content date

sendMessage :: String -> MDateTime -> IMModel -> NoMessages
sendMessage content date =
        case _ of
                model@(IMModel {
                        user: IMUser { id: senderID },
                        webSocket: Just (WS webSocket),
                        token: Just token,
                        chatting: Just chatting,
                        temporaryID,
                        contacts
                }) ->   let     recipient@(Contact {user: IMUser { id: recipientID }, history}) = contacts !@ chatting
                                newTemporaryID = temporaryID + SP.fromInt 1
                                updatedChatting = SN.updateContact recipient $ _ {
                                        history = DA.snoc history $ HistoryMessage {
                                                id: newTemporaryID,
                                                status: Unread,
                                                sender: senderID,
                                                recipient: recipientID,
                                                date,
                                                content
                                        }
                                }
                                updatedModel = SN.updateModel model $ _ {
                                        temporaryID = newTemporaryID,
                                        contacts = SU.unsafeFromJust "sendMessage" $ DA.updateAt chatting updatedChatting contacts
                                }
                        in  --needs to handle failure!
                                CIF.nothingNext updatedModel <<< liftEffect <<< CIW.sendPayload webSocket $ ServerMessage {
                                        id: newTemporaryID,
                                        user: recipientID,
                                        token: token,
                                        content
                                }
                model -> CIF.nothingNext model <<< liftEffect $ EC.log "Invalid sendMessage state"

receiveMessage :: Boolean -> IMModel -> WebSocketPayloadClient -> MoreMessages
receiveMessage isFocused model@(IMModel {
        user: IMUser { id: recipientID },
        contacts,
        suggesting,
        chatting,
        suggestions
}) =
        case _ of
                Received { previousID, id } -> F.noMessages <<< SN.updateModel model $ _ {
                        contacts = DM.fromMaybe contacts $ updateTemporaryID contacts previousID id
                }
                ClientMessage m@{ user } ->
                        case processIncomingMessage m of
                                updatedModel@(IMModel {
                                        token: Just tk,
                                        webSocket: Just (WS ws),
                                        chatting: Just index,
                                        contacts
                                }) ->   --mark it as read if we received a message from the current chat
                                        let fields = {
                                                token: tk,
                                                webSocket: ws,
                                                chatting: index,
                                                userID: recipientID,
                                                contacts
                                        } in    if isFocused && isChatting user fields then
                                                        CICN.updateReadHistory updatedModel fields
                                                 else
                                                        F.noMessages updatedModel
                                updatedModel -> F.noMessages updatedModel
        where   getUserID :: forall n a. Newtype n { id :: PrimaryKey | a } => Maybe n -> Maybe PrimaryKey
                getUserID = map (_.id <<< DN.unwrap)
                suggestingContact = do
                        index <- suggesting
                        suggestions !! index
                isChatting sender {contacts, chatting} =
                        --REFACTOR: helpers for Contact to pull out fields
                        let (Contact {user: IMUser {id: recipientID}}) = contacts !@ chatting in recipientID == DET.either (_.id <<< DN.unwrap) identity sender

                processIncomingMessage m =
                        case SU.unsafeFromJust "receiveMessage" $ updateHistoryMessage contacts recipientID m of
                                New contacts' ->
                                        --new messages bubble the contact to the top
                                        let added = DA.head contacts' in
                                        --edge case of recieving a message from a suggestion
                                         if getUserID (map (_.user <<< DN.unwrap) added) == getUserID suggestingContact then
                                                SN.updateModel model $ _ {
                                                        contacts = contacts',
                                                        suggesting = Nothing,
                                                        suggestions = SU.unsafeFromJust "delete receiveMesage" do
                                                                index <- suggesting
                                                                DA.deleteAt index suggestions,
                                                        chatting = Just 0
                                                }
                                          else
                                                SN.updateModel model $ _ {
                                                        contacts = contacts'
                                                }
                                Existing contacts' -> SN.updateModel model $ _ {
                                        contacts = contacts'
                                }

updateHistoryMessage :: Array Contact -> PrimaryKey -> {
        id :: PrimaryKey,
        user :: Either IMUser PrimaryKey,
        date :: MDateTime,
        content :: String
} -> Maybe (ReceivedUser (Array Contact))
updateHistoryMessage contacts recipientID { id, user, date, content } =
        case user of
                Right userID@(PrimaryKey _) -> do
                        index <- DA.findIndex (findUser userID) contacts
                        Contact { history } <- contacts !! index

                        map Existing $ DA.modifyAt index (updateHistory { userID, content, id, date }) contacts
                Left user@(IMUser { id: userID }) -> Just <<< New $ updateHistory { userID, content, id, date } (Contact {user, history: [], chatStarter: userID} ) : contacts

        where   findUser userID (Contact { user: IMUser { id } }) = userID == id

                updateHistory { id, userID, content, date } user@(Contact {history}) = SN.updateContact user $ _ {
                        history = DA.snoc history $ HistoryMessage {
                                status: Unread,
                                sender: userID,
                                recipient: recipientID,
                                id,
                                content,
                                date
                        }
                }

updateTemporaryID :: Array Contact -> PrimaryKey -> PrimaryKey -> Maybe (Array Contact)
updateTemporaryID contacts previousID id = do
        index <- DA.findIndex (findUser previousID) contacts
        Contact { history } <- contacts !! index
        innerIndex <- DA.findIndex (findTemporary previousID) history

        DA.modifyAt index (updateTemporary innerIndex id) contacts

        where   findTemporary previousID (HistoryMessage { id }) = id == previousID
                findUser previousID (Contact { history }) = DA.any (findTemporary previousID) history

                updateTemporary index newID user@(Contact { history }) = SN.updateContact user $ _ {
                        history = SU.unsafeFromJust "receiveMessage" $ DA.modifyAt index (flip SN.updateHistoryMessage (_ { id = newID })) history
                }