#!/bin/bash
# RubaiSTT — doimiy self-signed code-signing sertifikati (login keychain).
# Maqsad: har build'da bir xil sertifikat bilan imzolash, shunda macOS TCC
# (Accessibility/Microphone) ruxsatlari cdhash'ga emas, sertifikatga bog'lanadi
# va qayta build ruxsatni buzmaydi.
#
# Idempotent: sertifikat allaqachon bo'lsa, hech narsa qilmaydi.
#   ./scripts/make_signing_cert.sh          -> yaratadi/tekshiradi, CN ni chiqaradi
#   ./scripts/make_signing_cert.sh --check  -> faqat mavjudligini tekshiradi (exit 0/1)
set -e
CN="${RUBAI_SIGN_CN:-RubaiSTT Local Signing}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

have_identity() {
    security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "\"$CN\""
}

if [ "$1" = "--check" ]; then
    have_identity && { echo "$CN"; exit 0; } || exit 1
fi

if have_identity; then
    echo "==> Imzolash sertifikati mavjud: \"$CN\" (qayta yaratilmaydi)"
    exit 0
fi

# Sertifikat bor, lekin identity sifatida yaroqsiz — odatda ishonch (trust) berilmagan.
# Faqat ishonch qadamini takrorlaymiz (qayta yaratmaymiz).
if security find-certificate -c "$CN" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "==> \"$CN\" keychain'da bor, lekin hali ishonchli emas — ishonch berilmoqda..."
    TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
    security find-certificate -c "$CN" -p "$KEYCHAIN" > "$TMP/cert.pem"
    if security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem" && have_identity; then
        echo "==> Tayyor: \"$CN\""; exit 0
    fi
    echo "!! Ishonch berib bo'lmadi. Qo'lda: Keychain Access → login → \"$CN\"" >&2
    echo "   → Get Info → Trust → Code Signing: Always Trust" >&2
    exit 1
fi

echo "==> \"$CN\" sertifikati yaratilmoqda (10 yil, faqat shu Mac uchun)..."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/ext.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $CN
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
CNF
openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/ext.cnf" >/dev/null 2>&1
# p12 (bo'sh parolsiz bo'lmaydi — vaqtinchalik parol)
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/id.p12" -passout pass:rubai -legacy 2>/dev/null \
 || openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/id.p12" -passout pass:rubai

# Login keychain'ga import; -T codesign'ga kalitdan so'ramasdan foydalanishga ruxsat.
security import "$TMP/id.p12" -k "$KEYCHAIN" -P rubai -f pkcs12 \
    -T /usr/bin/codesign -T /usr/bin/security >/dev/null

# codeSign uchun ishonch (user domain). GUI parol so'rovi chiqishi mumkin.
echo "==> Sertifikatga codeSigning ishonchi berilmoqda (parol so'ralsa — Mac parolingiz)..."
if ! security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem" 2>/dev/null; then
    echo "!! Avtomatik ishonch berib bo'lmadi. Qo'lda: Keychain Access → login → \"$CN\"" >&2
    echo "   → Get Info → Trust → Code Signing: Always Trust" >&2
fi

if have_identity; then
    echo "==> Tayyor: \"$CN\""
    security find-identity -v -p codesigning "$KEYCHAIN" | grep "\"$CN\""
else
    echo "!! Sertifikat yaratildi, lekin codesigning identity sifatida hali ko'rinmayapti (ishonch yo'q)." >&2
    exit 1
fi
