# Card states

The card opens on hover with a short dismissal delay for crossing into it.
Right-click pins it open; clicking outside dismisses it. Left-click on the bar
still sends a wave. The card offers the same action, plus Explore, Invite and
collapsed Settings. Short screens scroll the card content.

| State | What the card communicates |
| --- | --- |
| Starting / reconnecting | Connection returns automatically; wave action waits. |
| Prolonged outage | Still retrying, without suggesting the community is empty. |
| Identity failure | Local identity needs attention, with its directory shown. |
| Installed update / missing service | Shell restart required. |
| Ready | A hello is available; Send a wave. |
| Sending | Request is in flight; repeated sends disabled. |
| Received wave | Country or “Someone, somewhere”; no implication of a direct reply. |
| Received baton | Sender’s country and the baton’s aggregate story. |
| Orphan baton assigned | A baton found you, without inventing a sender. |
| Holding baton | Hops, age and countries; Pass the baton when ready. |
| Holding during cooldown | Baton stays visible with the relay’s remaining wait. |
| Confirmed delivery / pass | Acknowledges only confirmed outcomes. |
| Empty room | Nobody available for the last attempt; short retry countdown. |
| Cooldown | Next-wave countdown; incoming waves remain possible. |
| Failed request | Delivery unconfirmed; reconnect to reconcile authoritative state. |
| Update available | Update command shown alongside the current state. |

Connection/recovery and pending work take precedence over event celebrations.
Incoming and delivery headlines last 15 seconds, then return to the current
action state. The last incoming country remains visible during this session.
The received-country set remains local, as in the original experiment.
Unknown community stats show a dash; disconnected totals are labelled as last
known. The existing showCounter setting also hides the worldwide card total.

Ownership, eligibility, and cooldown still come from the existing relay
protocol. No server changes or new endpoints. The card never sends on opening.

Validation: `node dev/model-test.js`, `omarchy plugin validate .`, and
`bash dev/card-preview.sh`.
