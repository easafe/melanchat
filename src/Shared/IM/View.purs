module Shared.IM.View where

import Prelude
import Shared.Types

import Flame (Html)
import Flame.HTML.Attribute as HA
import Flame.HTML.Element as HE
import Shared.IM.View.Chat as SIVC
import Shared.IM.View.Contacts as SIVCN
import Shared.IM.View.History as SIVH
import Shared.IM.View.Profile as SIVS
import Shared.IM.View.UserMenu as SIVU
import Shared.Unsafe ((!@))

view :: Boolean -> IMModel -> Html IMMessage
view isClientRender model@{ suggestions, suggesting, chatting, contacts, hasTriedToConnectYet, isWebSocketConnected, toggleModal } = HE.div (HA.class' "im") [
      HE.div (HA.class' "left-box") [
            SIVU.userMenu model,
            search model,
            SIVCN.contactList isClientRender model ,
            logo,

            modals toggleModal
      ],
      HE.div [HA.class' "chat-box", HA.onDragenter' PreventStop, HA.onDragover' PreventStop, HA.onDrop' DropFile] [
            HE.div (HA.class' {"no-connection": true, flexed: hasTriedToConnectYet && not isWebSocketConnected}) "Connection to the server lost. Attempting to automaticaly reconnect...",
            SIVS.profile model,
            SIVH.history model $ map (contacts !@ _ ) chatting,
            SIVC.chat  model
      ]
]

search :: IMModel -> Html IMMessage
search model = HE.div' $ HA.class' "search"

logo :: Html IMMessage
logo = HE.div (HA.class' "logo-contact-list") [
      HE.img $ HA.src "/client/media/logo-small.png"
]

modals :: ShowUserMenuModal -> Html IMMessage
modals toggle =
      HE.div (HA.class' {"modal-placeholder-overlay": true, "hidden" : toggle == HideUserMenuModal}) [
            HE.div (HA.class' { confirmation: true, hidden: toggle /= ConfirmLogout}) [
                  HE.span (HA.class' "bold") "Do you really want to log out?",
                  HE.div (HA.class' "buttons") [
                        HE.button [HA.class' "cancel", HA.onClick (ToggleModal HideUserMenuModal)] "Cancel",
                        HE.button [HA.class' "green-button danger", HA.onClick Logout] "Logout"
                  ]
            ],
            HE.div (HA.class' { "modal-placeholder": true, hidden: toggle == ConfirmLogout }) [ --snabbdom is a little shit about if and else html
                  HE.div (HA.class' "modal-menu") [
                        HE.div [HA.onClick (ToggleModal HideUserMenuModal), HA.class' "back"] [
                              HE.svg [HA.class' "svg-16", HA.viewBox "0 0 512 512"] [
                                    HE.polygon' [HA.points "496 159.961 295.983 159.961 295.976 16.024 257.698 16.024 17.364 255.706 257.313 495.941 296.001 495.976 295.993 351.961 496 351.961 496 159.961"]
                              ],
                              HE.text " Back to chats"
                        ],
                        HE.div [HA.onClick (ToggleModal ShowProfile), HA.class' { entry: true, selected: toggle == ShowProfile }] "Your profile",
                        HE.div [HA.onClick (ToggleModal ShowSettings), HA.class' { entry: true, selected: toggle == ShowSettings }] "Your settings",
                        HE.div [HA.onClick (ToggleModal ShowLeaderboard), HA.class' { entry: true, selected: toggle == ShowLeaderboard }] "Karma leaderboard",
                        HE.div [HA.onClick (ToggleModal ShowHelp), HA.class' { entry: true, selected: toggle == ShowHelp }] "Help"
                  ],
                  HE.div [HA.id "profile-edition-root", HA.class' { hidden: toggle /= ShowProfile }] $ HE.div' (HA.class' "loading"),
                  HE.div [HA.id "settings-edition-root", HA.class' { hidden: toggle /= ShowSettings }] $ HE.div' (HA.class' "loading"),
                  HE.div [HA.id "karma-leaderboard-root", HA.class' { hidden: toggle /= ShowLeaderboard }] $ HE.div' (HA.class' "loading"),
                  HE.div [HA.id "help-root", HA.class' { hidden: toggle /= ShowHelp }] $ HE.div' (HA.class' "loading")
            ]
      ]