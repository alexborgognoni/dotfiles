// Java trust store from a PEM bundle: java TrustStore.java <bundle.pem> <out.p12>
// (corporate/java-truststore.nix). A certificate Java cannot parse is skipped and
// reported, not fatal: one odd certificate must not leave Java without the rest.
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.KeyStore;
import java.security.cert.CertificateFactory;
import java.util.regex.*;

public class TrustStore {
  public static void main(String[] args) throws Exception {
    String pem = Files.readString(Path.of(args[0]), StandardCharsets.ISO_8859_1);
    Matcher blocks =
        Pattern.compile("-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", Pattern.DOTALL)
            .matcher(pem);
    CertificateFactory factory = CertificateFactory.getInstance("X.509");
    KeyStore store = KeyStore.getInstance("PKCS12");
    store.load(null, null);
    int added = 0;
    int skipped = 0;
    while (blocks.find()) {
      try (InputStream in =
          new ByteArrayInputStream(blocks.group().getBytes(StandardCharsets.ISO_8859_1))) {
        store.setCertificateEntry("ca-" + added, factory.generateCertificate(in));
        added++;
      } catch (Exception e) {
        skipped++;
        System.err.println("skipped a certificate: " + e.getMessage());
      }
    }
    if (added == 0) {
      System.err.println("no certificate in " + args[0]);
      System.exit(1);
    }
    try (OutputStream out = new FileOutputStream(args[1])) {
      store.store(out, "changeit".toCharArray());
    }
    System.out.println(added + " certificates, " + skipped + " skipped");
  }
}
