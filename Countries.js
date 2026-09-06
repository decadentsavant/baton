// ISO 3166-1 alpha-2 -> display name, trimmed to the countries that actually
// show up in Omarchy's download stats. Unlisted codes fall back to the bare
// code in Model.originLabel, which reads fine ("Someone in NZ") and keeps this
// file from turning into a 250-entry maintenance chore.
var NAMES = {
  AE: "the UAE", AR: "Argentina", AT: "Austria", AU: "Australia", BE: "Belgium",
  BG: "Bulgaria", BR: "Brazil", CA: "Canada", CH: "Switzerland", CL: "Chile",
  CN: "China", CO: "Colombia", CZ: "Czechia", DE: "Germany", DK: "Denmark",
  EE: "Estonia", EG: "Egypt", ES: "Spain", FI: "Finland", FR: "France",
  GB: "the UK", GR: "Greece", HK: "Hong Kong", HR: "Croatia", HU: "Hungary",
  ID: "Indonesia", IE: "Ireland", IL: "Israel", IN: "India", IS: "Iceland",
  IT: "Italy", JP: "Japan", KE: "Kenya", KR: "South Korea", LT: "Lithuania",
  LV: "Latvia", MA: "Morocco", MX: "Mexico", MY: "Malaysia", NG: "Nigeria",
  NL: "the Netherlands", NO: "Norway", NZ: "New Zealand", PE: "Peru",
  PH: "the Philippines", PK: "Pakistan", PL: "Poland", PT: "Portugal",
  RO: "Romania", RS: "Serbia", SE: "Sweden", SG: "Singapore", SI: "Slovenia",
  SK: "Slovakia", TH: "Thailand", TR: "Türkiye", TW: "Taiwan", UA: "Ukraine",
  US: "the US", VN: "Vietnam", ZA: "South Africa"
}
