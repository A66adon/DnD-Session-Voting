package ds.dnd.voting.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.List;


@NoArgsConstructor
@Getter
@Setter
@Entity
public class Vote {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long voteId;

    @Column(nullable = false)
    private String voterName;

    @ManyToMany
    @JoinTable(
            name = "vote_timeslots",
            joinColumns = @JoinColumn(name = "vote_id"),
            inverseJoinColumns = @JoinColumn(name = "timeslot_id")
    )
    @JsonIgnoreProperties({"votingWeek"})
    private List<TimeSlot> timeslots;

    @ManyToMany
    @JoinTable(
            name = "vote_preferred_timeslots",
            joinColumns = @JoinColumn(name = "vote_id"),
            inverseJoinColumns = @JoinColumn(name = "timeslot_id")
    )
    @JsonIgnoreProperties({"votingWeek"})
    private List<TimeSlot> preferredTimeSlots;

    public Vote(String voterName, List<TimeSlot> timeslots) {
        this.voterName = voterName;
        this.timeslots = timeslots;
    }

    public Vote(String voterName, List<TimeSlot> timeslots, List<TimeSlot> preferredTimeSlots) {
        this.voterName = voterName;
        this.timeslots = timeslots;
        this.preferredTimeSlots = preferredTimeSlots;
    }

}
