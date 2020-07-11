module Test.Client.IM.Contacts where

import Client.IM.Contacts as CICN
import Data.Maybe (Maybe(..))
import Data.Newtype as DN
import Data.Tuple (Tuple(..))
import Data.Tuple as DT
import Effect.Now as EN
import Effect.Unsafe as EU
import Prelude (discard, map, ($), (<<<))
import Shared.IM.Types (Contact, HistoryMessage(..), IMModel(..), MessageStatus(..))
import Shared.Newtype as SN
import Shared.PrimaryKey as SP
import Shared.Types (MDateTime(..), PrimaryKey(..))
import Shared.Unsafe ((!@))
import Test.Client.Model (contact, imUser)
import Test.Client.Model as TCM
import Test.Unit (TestSuite)
import Test.Unit as TU
import Test.Unit.Assert as TUA

tests :: TestSuite
tests = do
        TU.suite "im contacts update" $ do
                TU.test "resumeChat resets suggesting" $ do
                        let IMModel { suggesting } = DT.fst <<< CICN.resumeChat anotherContactID <<< SN.updateModel model $ _ {
                                suggesting = Just 4455
                        }
                        TUA.equal Nothing suggesting

                TU.test "resumeChat sets chatting" $ do
                        let m@(IMModel { chatting }) = DT.fst <<< CICN.resumeChat (SP.fromInt 32) <<< SN.updateModel model $ _ {
                                chatting = Nothing
                        }
                        TUA.equal (Just 1) chatting

                        let IMModel { chatting } = DT.fst $ CICN.resumeChat anotherContactID m
                        TUA.equal (Just 0) chatting

                TU.test "markRead sets recieved messages as read" $ do
                        let IMModel { contacts } = DT.fst <<< CICN.markRead <<< SN.updateModel model $ _ {
                                chatting = Just 1
                        }
                        TUA.equal [Tuple (SP.fromInt 1) Read, Tuple (SP.fromInt 2) Unread, Tuple (SP.fromInt 3) Read] <<< map (\(HistoryMessage { id, status}) -> Tuple id status) <<< _.history $ DN.unwrap (contacts !@ 1)

model :: IMModel
model = SN.updateModel TCM.model $ _ {
        contacts = [contact, anotherContact]
}

anotherContactID :: PrimaryKey
anotherContactID = SP.fromInt 23

anotherContact :: Contact
anotherContact = SN.updateContact contact $ _ {
        user = SN.updateUser imUser $ _ { id = anotherContactID },
        history = [
                HistoryMessage {
                       id: SP.fromInt 1,
                       status: Unread,
                       sender: SP.fromInt 32,
                       recipient: _.id $ DN.unwrap imUser,
                       content: "1",
                       date: EU.unsafePerformEffect $ map MDateTime EN.nowDateTime
                },
                HistoryMessage {
                       id: SP.fromInt 2,
                       status: Unread,
                       sender: _.id $ DN.unwrap imUser,
                       recipient: SP.fromInt 32,
                       content: "2",
                       date: EU.unsafePerformEffect $ map MDateTime EN.nowDateTime
                },
                HistoryMessage {
                       id: SP.fromInt 3,
                       status: Unread,
                       sender: SP.fromInt 32,
                       recipient: _.id $ DN.unwrap imUser,
                       content: "3",
                       date: EU.unsafePerformEffect $ map MDateTime EN.nowDateTime
                }
        ]
}