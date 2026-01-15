import { Head } from "@inertiajs/react";
import { Button, Box, Flex, Heading, Text, Container, Section } from "@radix-ui/themes";

function LandingShow() {
  return (
    <>
      <Head title="Invoicebot - Automatically Match Invoices from Gmail to Your Bank" />

      {/* Header */}
      <Box style={{
        borderBottom: "1px solid var(--gray-a5)",
        backgroundColor: "var(--color-background)",
        position: "sticky",
        top: 0,
        zIndex: 50
      }}>
        <Container size="4">
          <Flex justify="between" align="center" py="4">
            <Heading size="6" style={{ color: "var(--accent-9)" }}>
              Invoicebot
            </Heading>
            <Button variant="soft" size="2">
              Login
            </Button>
          </Flex>
        </Container>
      </Box>

      {/* Hero Section */}
      <Section size="3">
        <Container size="3">
          <Flex direction="column" align="center" gap="6" style={{ textAlign: "center", paddingTop: "var(--space-9)" }}>
            <Box style={{ width: "100%" }}>
              <Heading size="9" mb="4" style={{
                maxWidth: "800px",
                margin: "0 auto",
                lineHeight: 1.1,
                background: "linear-gradient(135deg, var(--accent-11) 0%, var(--accent-9) 100%)",
                WebkitBackgroundClip: "text",
                WebkitTextFillColor: "transparent"
              }}>
                Automatically match invoices from Gmail to your bank
              </Heading>
              <Text size="5" color="gray" style={{ maxWidth: "600px", margin: "0 auto" }}>
                Stop manually searching through emails for invoices. Let Invoicebot find them in your Gmail and pair them with your bank transactions automatically.
              </Text>
            </Box>
          </Flex>
        </Container>
      </Section>

      {/* Footer */}
      <Box style={{
        borderTop: "1px solid var(--gray-a5)",
        backgroundColor: "var(--gray-a2)",
        padding: "var(--space-6) 0",
        position: "fixed",
        bottom: 0,
        left: 0,
        right: 0
      }}>
        <Container size="4">
          <Flex justify="between" align="center">
            <Text size="2" color="gray">
              © 2025 Invoicebot
            </Text>
            <Text size="2" color="gray">
              Created by{" "}
              <a
                href="https://x.com/_vojto"
                target="_blank"
                rel="noopener noreferrer"
                style={{
                  color: "var(--accent-11)",
                  textDecoration: "none"
                }}
              >
                Vojtech Rinik
              </a>
            </Text>
          </Flex>
        </Container>
      </Box>
    </>
  );
}

// Disable the default layout for the landing page
LandingShow.layout = (page: React.ReactNode) => page;

export default LandingShow;
