import java.io.InputStream;
import java.nio.file.Path;
import java.security.CodeSigner;
import java.security.MessageDigest;
import java.security.cert.Certificate;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.Set;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

/** Read every bundle entry so the JDK checks its signature and content digest. */
class VerifyBundle {
    public static void main(String[] args) throws Exception {
        if (args.length != 2) throw new IllegalArgumentException("Expected bundle path and certificate SHA-256.");
        int verifiedEntries = 0;
        Set<String> names = new HashSet<>();
        try (JarFile bundle = new JarFile(Path.of(args[0]).toFile(), true)) {
            var entries = bundle.entries();
            byte[] buffer = new byte[65536];
            while (entries.hasMoreElements()) {
                JarEntry entry = entries.nextElement();
                if (!names.add(entry.getName())) throw new SecurityException("Duplicate bundle entry.");
                if (entry.isDirectory()) continue;
                try (InputStream input = bundle.getInputStream(entry)) {
                    while (input.read(buffer) != -1) { /* Trigger JAR verification. */ }
                }
                // Only the JAR's own signing metadata may be unsigned.
                String name = entry.getName().toUpperCase(java.util.Locale.ROOT);
                boolean signatureMetadata = name.equals("META-INF/MANIFEST.MF")
                    || (name.startsWith("META-INF/") && name.indexOf('/', 9) == -1
                        && (name.endsWith(".SF") || name.endsWith(".RSA")
                            || name.endsWith(".DSA") || name.endsWith(".EC")));
                if (signatureMetadata) continue;
                CodeSigner[] signers = entry.getCodeSigners();
                if (signers == null || signers.length != 1) throw new SecurityException("Missing or unexpected bundle signer.");
                Certificate certificate = signers[0].getSignerCertPath().getCertificates().get(0);
                String fingerprint = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(certificate.getEncoded()));
                if (!fingerprint.equalsIgnoreCase(args[1])) throw new SecurityException("Bundle signer does not match the upload key.");
                verifiedEntries++;
            }
        }
        if (verifiedEntries == 0) throw new SecurityException("Bundle has no signed content.");
        System.out.println("{\"verifiedEntries\":" + verifiedEntries + ",\"certificateSha256\":\"" + args[1] + "\"}");
    }
}
