package ds.dnd.voting.repositories;

import ds.dnd.voting.model.VotingUser;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface VotingUserRepository extends JpaRepository<VotingUser, Long> {

    Optional<VotingUser> findByName(String name);
}


