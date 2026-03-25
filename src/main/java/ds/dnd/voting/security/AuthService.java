package ds.dnd.voting.security;

import ds.dnd.voting.dto.LoginRequestDTO;
import ds.dnd.voting.dto.LoginResponseDTO;
import ds.dnd.voting.model.VotingUser;
import ds.dnd.voting.repositories.VotingUserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final JwtService jwtService;
    private final VotingUserRepository votingUserRepository;

    @Value("${app.voting.password}")
    private String votingPassword;

    /**
     * Authenticate user with fixed password
     * Returns JWT token if successful
     */
    @Transactional
    public LoginResponseDTO login(LoginRequestDTO request) {
        String username = request.getUsername();
        String password = request.getPassword();

        String cleanedUsername = username == null ? "" : username.trim();

        // Validate username
        if (cleanedUsername.isEmpty()) {
            throw new RuntimeException("Username cannot be empty");
        }

        if (cleanedUsername.length() > 50) {
            throw new RuntimeException("Username too long");
        }

        // Check password
        if (!votingPassword.equals(password)) {
            log.warn("Failed login attempt for username: {}", cleanedUsername);
            throw new RuntimeException("Invalid password");
        }

        VotingUser user = findOrCreateUser(cleanedUsername);

        // Generate token
        String token = jwtService.generateToken(user.getName());

        log.info("Successful login for user: {}", user.getName());

        return new LoginResponseDTO(
                token,
                user.getName(),
                "Login successful"
        );
    }

    private VotingUser findOrCreateUser(String cleanedUsername) {
        return votingUserRepository.findByName(cleanedUsername)
                .orElseGet(() -> votingUserRepository.save(new VotingUser(cleanedUsername)));
    }

    /**
     * Validate token and extract username
     */
    public String validateTokenAndGetUsername(String token) {
        if (token == null || token.trim().isEmpty()) {
            return null;
        }

        // Remove "Bearer " prefix if present
        if (token.startsWith("Bearer ")) {
            token = token.substring(7);
        }

        if (!jwtService.validateToken(token)) {
            return null;
        }

        return jwtService.getUsernameFromToken(token);
    }
}

