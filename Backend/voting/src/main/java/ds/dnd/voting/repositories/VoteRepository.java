package ds.dnd.voting.repositories;

import ds.dnd.voting.model.Vote;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VoteRepository extends JpaRepository<Vote, Long> {
}
